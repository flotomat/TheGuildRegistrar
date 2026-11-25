package main

import (
	"errors"
	"strings"
	"testing"
)

func init() { inviteIterations = 1000 } // keep tests fast

const testToken = "MTIzNDU2Nzg5.abcdef.ghijklmnopqrstuvwxyz"

func TestInviteRoundTripGenerated(t *testing.T) {
	pw, err := GeneratePassword()
	if err != nil {
		t.Fatal(err)
	}
	code, err := CreateInvite(testToken, "42", pw)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(code, invitePrefix) || strings.Contains(code, testToken) {
		t.Fatalf("unexpected code %q", code)
	}
	inv, err := RedeemInvite(code, pw)
	if err != nil {
		t.Fatal(err)
	}
	if inv.Token != testToken || inv.GuildID != "42" {
		t.Fatalf("got %+v", inv)
	}
	// generated passwords may be typed in lower case and without dashes
	if _, err := RedeemInvite(code, strings.ToLower(strings.ReplaceAll(pw, "-", " "))); err != nil {
		t.Fatalf("normalized password rejected: %v", err)
	}
	// line breaks inserted by chat programs are ignored
	if _, err := RedeemInvite(code[:20]+"\n"+code[20:], pw); err != nil {
		t.Fatalf("code with line break rejected: %v", err)
	}
}

func TestInviteRoundTripManual(t *testing.T) {
	code, err := CreateInvite(testToken, "", "Gilde!Raid-Abend#42")
	if err != nil {
		t.Fatal(err)
	}
	inv, err := RedeemInvite(code, "  Gilde!Raid-Abend#42 ")
	if err != nil || inv.Token != testToken || inv.GuildID != "" {
		t.Fatalf("got %+v, %v", inv, err)
	}
	// manual passwords are case sensitive
	if _, err := RedeemInvite(code, "gilde!raid-abend#42"); !errors.Is(err, ErrInvitePassword) {
		t.Fatalf("want ErrInvitePassword, got %v", err)
	}
}

func TestInviteErrors(t *testing.T) {
	code, _ := CreateInvite(testToken, "42", "secret")
	if _, err := RedeemInvite(code, "wrong"); !errors.Is(err, ErrInvitePassword) {
		t.Errorf("wrong password: got %v", err)
	}
	if _, err := RedeemInvite(code, "   "); !errors.Is(err, ErrEmptyPassword) {
		t.Errorf("empty password: got %v", err)
	}
	if _, err := CreateInvite(testToken, "42", ""); !errors.Is(err, ErrEmptyPassword) {
		t.Errorf("create with empty password: got %v", err)
	}
	// tampered ciphertext
	raw := []byte(code)
	i := len(raw) - 5
	if raw[i] == 'A' {
		raw[i] = 'B'
	} else {
		raw[i] = 'A'
	}
	if _, err := RedeemInvite(string(raw), "secret"); !errors.Is(err, ErrInvitePassword) {
		t.Errorf("tampered code: got %v", err)
	}
	for _, bad := range []string{"", "hello", "TGRK2-" + strings.TrimPrefix(code, invitePrefix), invitePrefix + "!!!", invitePrefix + "AAAA"} {
		if _, err := RedeemInvite(bad, "secret"); !errors.Is(err, ErrInviteFormat) {
			t.Errorf("%q: want ErrInviteFormat, got %v", bad, err)
		}
	}
}

func TestGeneratePassword(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 50; i++ {
		pw, err := GeneratePassword()
		if err != nil {
			t.Fatal(err)
		}
		if len(pw) != 24 || strings.Count(pw, "-") != 4 {
			t.Fatalf("bad format %q", pw)
		}
		for _, c := range strings.ReplaceAll(pw, "-", "") {
			if !strings.ContainsRune(passwordAlphabet, c) {
				t.Fatalf("bad char %q in %q", c, pw)
			}
		}
		if normalizeGenerated(pw) != pw {
			t.Fatalf("normalize changed %q", pw)
		}
		if seen[pw] {
			t.Fatalf("duplicate %q", pw)
		}
		seen[pw] = true
		if r := RatePassword(pw); r.Level != "strong" {
			t.Fatalf("generated password rated %s: %q", r.Level, pw)
		}
	}
}

func TestRatePassword(t *testing.T) {
	cases := map[string]string{
		"":                                   "weak",
		"abc":                                "weak",
		"aaaaaaaaaaaa":                       "weak",
		"12345678":                           "weak",
		"abcdefghijklmnop":                   "weak",
		"Sommer2026":                         "medium",
		"Gilde!Raid-Abend#42":                "strong",
		"korrekt pferd batterie heftklammer": "strong",
	}
	for pw, want := range cases {
		if got := RatePassword(pw); got.Level != want {
			t.Errorf("%q: got %s (score %d, hints %v), want %s", pw, got.Level, got.Score, got.Hints, want)
		}
	}
	r := RatePassword("abc")
	for _, h := range []string{"length", "upper", "digit", "special"} {
		if !contains(r.Hints, h) {
			t.Errorf("hints for abc miss %q: %v", h, r.Hints)
		}
	}
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
