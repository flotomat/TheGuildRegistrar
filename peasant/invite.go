// Peasant (The Guild Registrar) - invite codes: share the bot with other officers without
// showing the token. The code holds the token encrypted with a password (PBKDF2 + AES-GCM).
package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"unicode"
)

const (
	invitePrefix   = "TGRK1-"
	inviteSaltLen  = 16
	inviteNonceLen = 12
	inviteKeyLen   = 32
	// passwordAlphabet has no easily confused characters (no I, O, 0, 1).
	passwordAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	passwordGroups   = 5
	passwordGroupLen = 4
)

// inviteIterations is the PBKDF2 work factor (a variable only so tests can run faster).
var inviteIterations = 600_000

var (
	ErrInviteFormat   = errors.New("this is not a valid invite code")
	ErrInvitePassword = errors.New("wrong password (or the invite code is damaged)")
	ErrEmptyPassword  = errors.New("the password must not be empty")
)

// Invite is the content of an invite code.
type Invite struct {
	V       int    `json:"v"`
	Token   string `json:"token"`
	GuildID string `json:"guildId,omitempty"`
}

// GeneratePassword returns a random password like "ABCD-EFGH-JKLM-NPQR-STUV" (100 bits).
func GeneratePassword() (string, error) {
	buf := make([]byte, passwordGroups*passwordGroupLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	var sb strings.Builder
	for i, b := range buf {
		if i > 0 && i%passwordGroupLen == 0 {
			sb.WriteByte('-')
		}
		sb.WriteByte(passwordAlphabet[int(b)%len(passwordAlphabet)]) // 256 % 32 == 0: no bias
	}
	return sb.String(), nil
}

// normalizeGenerated turns a typed generated password ("abcd efgh ...") into its canonical form.
// It returns "" if the input cannot be a generated password.
func normalizeGenerated(pw string) string {
	var chars []byte
	for _, r := range strings.ToUpper(pw) {
		switch {
		case r == '-' || unicode.IsSpace(r):
			continue
		case r < 128 && strings.IndexByte(passwordAlphabet, byte(r)) >= 0:
			chars = append(chars, byte(r))
		default:
			return ""
		}
	}
	if len(chars) != passwordGroups*passwordGroupLen {
		return ""
	}
	var sb strings.Builder
	for i, c := range chars {
		if i > 0 && i%passwordGroupLen == 0 {
			sb.WriteByte('-')
		}
		sb.WriteByte(c)
	}
	return sb.String()
}

func inviteKey(password string, salt []byte) ([]byte, error) {
	return pbkdf2.Key(sha256.New, password, salt, inviteIterations, inviteKeyLen)
}

func newGCM(key []byte) (cipher.AEAD, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}

// CreateInvite encrypts the token (and the selected server) with the password.
func CreateInvite(token, guildID, password string) (string, error) {
	password = strings.TrimSpace(password)
	if password == "" {
		return "", ErrEmptyPassword
	}
	plain, err := json.Marshal(Invite{V: 1, Token: token, GuildID: guildID})
	if err != nil {
		return "", err
	}
	buf := make([]byte, inviteSaltLen+inviteNonceLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	salt, nonce := buf[:inviteSaltLen], buf[inviteSaltLen:]
	key, err := inviteKey(password, salt)
	if err != nil {
		return "", err
	}
	gcm, err := newGCM(key)
	if err != nil {
		return "", err
	}
	sealed := gcm.Seal(buf, nonce, plain, []byte(invitePrefix))
	return invitePrefix + base64.RawURLEncoding.EncodeToString(sealed), nil
}

// RedeemInvite decrypts an invite code.
func RedeemInvite(code, password string) (Invite, error) {
	code = strings.Join(strings.Fields(code), "") // tolerate line breaks from chat programs
	if !strings.HasPrefix(code, invitePrefix) {
		return Invite{}, ErrInviteFormat
	}
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(code, invitePrefix))
	if err != nil || len(raw) < inviteSaltLen+inviteNonceLen+16 {
		return Invite{}, ErrInviteFormat
	}
	password = strings.TrimSpace(password)
	if password == "" {
		return Invite{}, ErrEmptyPassword
	}
	candidates := []string{password}
	if n := normalizeGenerated(password); n != "" && n != password {
		candidates = append(candidates, n)
	}
	salt, nonce, sealed := raw[:inviteSaltLen], raw[inviteSaltLen:inviteSaltLen+inviteNonceLen], raw[inviteSaltLen+inviteNonceLen:]
	for _, pw := range candidates {
		key, err := inviteKey(pw, salt)
		if err != nil {
			return Invite{}, err
		}
		gcm, err := newGCM(key)
		if err != nil {
			return Invite{}, err
		}
		plain, err := gcm.Open(nil, nonce, sealed, []byte(invitePrefix))
		if err != nil {
			continue
		}
		var inv Invite
		if err := json.Unmarshal(plain, &inv); err != nil || inv.V != 1 || inv.Token == "" {
			return Invite{}, ErrInviteFormat
		}
		return inv, nil
	}
	return Invite{}, ErrInvitePassword
}

// PasswordRating is a rough strength estimate for a password chosen by hand.
type PasswordRating struct {
	Level string   `json:"level"` // weak, medium, strong
	Score int      `json:"score"`
	Hints []string `json:"hints"` // length, lower, upper, digit, special, variety
}

// RatePassword judges length, character classes and variety. It is a rough guide, not a guarantee.
func RatePassword(pw string) PasswordRating {
	runes := []rune(strings.TrimSpace(pw))
	n := len(runes)
	hints := []string{}

	score := 0
	switch {
	case n >= 20:
		score = 4
	case n >= 16:
		score = 3
	case n >= 12:
		score = 2
	case n >= 8:
		score = 1
	}
	if n < 12 {
		hints = append(hints, "length")
	}

	var lower, upper, digit, special bool
	distinct := map[rune]bool{}
	sequential := 0
	for i, r := range runes {
		distinct[r] = true
		switch {
		case unicode.IsLower(r):
			lower = true
		case unicode.IsUpper(r):
			upper = true
		case unicode.IsDigit(r):
			digit = true
		default:
			special = true
		}
		if i > 0 {
			d := r - runes[i-1]
			if d == 0 || d == 1 || d == -1 {
				sequential++
			}
		}
	}
	classes := 0
	for _, c := range []struct {
		ok   bool
		hint string
	}{{lower, "lower"}, {upper, "upper"}, {digit, "digit"}, {special, "special"}} {
		if c.ok {
			classes++
		} else {
			hints = append(hints, c.hint)
		}
	}
	if classes > 1 {
		score += classes - 1
	}

	// little variety: few different characters or mostly repeated/consecutive ones ("aaaa", "1234")
	if n > 0 && (len(distinct) < 4 || len(distinct)*3 <= n || (n > 3 && sequential*2 > n-1)) {
		score -= 2
		hints = append(hints, "variety")
	}
	if score < 0 {
		score = 0
	}

	level := "weak"
	switch {
	case score >= 5:
		level = "strong"
	case score >= 3:
		level = "medium"
	}
	return PasswordRating{Level: level, Score: score, Hints: hints}
}
