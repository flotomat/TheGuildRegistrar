// Peasant (The Guild Registrar) - local web interface (only reachable from this PC).
package main

import (
	"crypto/rand"
	"crypto/subtle"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

//go:embed web/index.html
var indexHTML string

type server struct {
	key      string
	addr     string
	mu       sync.Mutex
	token    string
	cfg      Config
	lastPing time.Time
	quit     chan struct{}
	quitOnce sync.Once
}

func (s *server) stop() {
	s.quitOnce.Do(func() { close(s.quit) })
}

func runServer(open bool) error {
	keyBytes := make([]byte, 24)
	if _, err := rand.Read(keyBytes); err != nil {
		return err
	}
	s := &server{key: hex.EncodeToString(keyBytes), cfg: loadConfig(), lastPing: time.Now(), quit: make(chan struct{})}
	if t, err := loadToken(); err == nil {
		s.token = t
	} else {
		fmt.Println("Note: the saved token could not be read:", err)
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	s.addr = ln.Addr().String()
	url := "http://" + s.addr + "/?k=" + s.key

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/api/state", s.api(s.handleState))
	mux.HandleFunc("/api/token", s.api(s.handleToken))
	mux.HandleFunc("/api/guilds", s.api(s.handleGuilds))
	mux.HandleFunc("/api/export", s.api(s.handleExport))
	mux.HandleFunc("/api/invite", s.api(s.handleInvite))
	mux.HandleFunc("/api/invite/rate", s.api(s.handleInviteRate))
	mux.HandleFunc("/api/invite/redeem", s.api(s.handleInviteRedeem))
	mux.HandleFunc("/api/ping", s.api(s.handlePing))
	mux.HandleFunc("/api/quit", s.api(s.handleQuit))
	srv := &http.Server{Handler: s.guard(mux), ReadHeaderTimeout: 10 * time.Second}

	fmt.Println("Peasant (The Guild Registrar)", version)
	fmt.Println()
	fmt.Println("The interface is running in your browser. If it did not open, copy this address:")
	fmt.Println("  " + url)
	fmt.Println()
	fmt.Println("Close this window (or click \"Quit\" in the browser) to stop Peasant.")

	if open {
		if err := openBrowser(url); err != nil {
			fmt.Println("Could not open the browser:", err)
		}
	}

	// stop when the browser page is gone for a while
	go func() {
		t := time.NewTicker(15 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				s.mu.Lock()
				idle := time.Since(s.lastPing)
				s.mu.Unlock()
				if idle > 10*time.Minute {
					fmt.Println("No browser activity for 10 minutes - stopping.")
					s.stop()
					return
				}
			case <-s.quit:
				return
			}
		}
	}()
	go func() {
		<-s.quit
		time.Sleep(300 * time.Millisecond)
		_ = srv.Close()
	}()

	err = srv.Serve(ln)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

// guard only accepts requests for our own host name (protects against DNS rebinding).
func (s *server) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Host != s.addr && !strings.HasPrefix(r.Host, "localhost:") {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

func (s *server) validKey(k string) bool {
	return subtle.ConstantTimeCompare([]byte(k), []byte(s.key)) == 1
}

func (s *server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" || !s.validKey(r.URL.Query().Get("k")) {
		http.Error(w, "Please use the address shown in the Peasant window.", http.StatusForbidden)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self'")
	page := strings.Replace(indexHTML, "{{KEY}}", s.key, 1)
	page = strings.Replace(page, "{{VERSION}}", version, 1)
	_, _ = w.Write([]byte(page))
}

type apiFunc func(r *http.Request) (any, error)

func (s *server) api(fn apiFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.validKey(r.Header.Get("X-TGR-Key")) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		s.mu.Lock()
		s.lastPing = time.Now()
		s.mu.Unlock()
		res, err := fn(r)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": errorCode(err), "message": err.Error()})
			return
		}
		_ = json.NewEncoder(w).Encode(res)
	}
}

func errorCode(err error) string {
	switch {
	case errors.Is(err, ErrInvalidToken):
		return "invalid_token"
	case errors.Is(err, ErrMissingIntent):
		return "missing_intent"
	case errors.Is(err, ErrInviteFormat):
		return "invite_format"
	case errors.Is(err, ErrInvitePassword):
		return "invite_password"
	case errors.Is(err, ErrEmptyPassword):
		return "empty_password"
	}
	var apiErr *APIError
	if errors.As(err, &apiErr) {
		if apiErr.Status == 404 || apiErr.Code == 10004 {
			return "guild_not_found"
		}
		return "discord_error"
	}
	return "error"
}

func (s *server) client() (*Client, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token == "" {
		return nil, errors.New("no token configured")
	}
	return NewClient(s.token), nil
}

type stateResponse struct {
	Version       string  `json:"version"`
	HasToken      bool    `json:"hasToken"`
	BotName       string  `json:"botName,omitempty"`
	AppID         string  `json:"appId,omitempty"`
	MembersIntent bool    `json:"membersIntent"`
	InviteURL     string  `json:"inviteUrl,omitempty"`
	PortalURL     string  `json:"portalUrl"`
	Guilds        []Guild `json:"guilds"`
	GuildID       string  `json:"guildId"`
	IncludeBots   bool    `json:"includeBots"`
	TokenStorage  string  `json:"tokenStorage"`
	TokenError    string  `json:"tokenError,omitempty"`
	FromInvite    bool    `json:"fromInvite"`
}

func (s *server) handleState(r *http.Request) (any, error) {
	st := stateResponse{Version: version, PortalURL: PortalURL(""), TokenStorage: tokenStorageInfo, Guilds: []Guild{}}
	s.mu.Lock()
	st.HasToken = s.token != ""
	st.GuildID = s.cfg.GuildID
	st.IncludeBots = s.cfg.IncludeBots
	st.FromInvite = s.cfg.FromInvite
	s.mu.Unlock()
	if !st.HasToken {
		return st, nil
	}
	c, _ := s.client()
	me, err := c.Me()
	if err != nil {
		st.TokenError = errorCode(err)
		return st, nil
	}
	st.BotName = me.Username
	if app, err := c.Application(); err == nil {
		st.AppID = app.ID
		st.MembersIntent = app.MembersIntent()
		st.InviteURL = InviteURL(app.ID)
		st.PortalURL = PortalURL(app.ID)
	}
	if guilds, err := c.Guilds(); err == nil {
		st.Guilds = guilds
	}
	return st, nil
}

func (s *server) handleToken(r *http.Request) (any, error) {
	switch r.Method {
	case http.MethodPost:
		var body struct {
			Token string `json:"token"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			return nil, err
		}
		token := strings.TrimSpace(body.Token)
		token = strings.TrimPrefix(token, "Bot ")
		if token == "" {
			return nil, errors.New("empty token")
		}
		if _, err := NewClient(token).Me(); err != nil {
			return nil, err
		}
		if err := saveToken(token); err != nil {
			return nil, fmt.Errorf("token is valid but could not be saved: %w", err)
		}
		s.mu.Lock()
		s.token = token
		s.cfg.FromInvite = false // own bot entered by hand
		cfg := s.cfg
		s.mu.Unlock()
		_ = saveConfig(cfg)
		return map[string]bool{"ok": true}, nil
	case http.MethodDelete:
		if err := deleteToken(); err != nil {
			return nil, err
		}
		s.mu.Lock()
		s.token = ""
		s.cfg.FromInvite = false
		cfg := s.cfg
		s.mu.Unlock()
		_ = saveConfig(cfg)
		return map[string]bool{"ok": true}, nil
	}
	return nil, errors.New("method not allowed")
}

func (s *server) handleGuilds(r *http.Request) (any, error) {
	c, err := s.client()
	if err != nil {
		return nil, err
	}
	return c.Guilds()
}

func (s *server) handleExport(r *http.Request) (any, error) {
	if r.Method != http.MethodPost {
		return nil, errors.New("method not allowed")
	}
	var body struct {
		GuildID     string `json:"guildId"`
		IncludeBots bool   `json:"includeBots"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		return nil, err
	}
	if body.GuildID == "" {
		return nil, errors.New("no server selected")
	}
	c, err := s.client()
	if err != nil {
		return nil, err
	}
	res, err := doExport(c, body.GuildID, ExportOptions{IncludeBots: body.IncludeBots}, nil)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	s.cfg.GuildID = body.GuildID
	s.cfg.IncludeBots = body.IncludeBots
	cfg := s.cfg
	s.mu.Unlock()
	_ = saveConfig(cfg)
	// the export is only returned to the page - it is not stored on disk or kept in the server
	return map[string]any{"text": res.Text, "members": res.Members, "roles": res.Roles, "skipped": res.Skipped, "server": res.Server}, nil
}

// handleInvite creates an invite code for another officer. Without a password one is generated.
// Neither the code nor the password is stored.
func (s *server) handleInvite(r *http.Request) (any, error) {
	if r.Method != http.MethodPost {
		return nil, errors.New("method not allowed")
	}
	var body struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		return nil, err
	}
	s.mu.Lock()
	token, guildID := s.token, s.cfg.GuildID
	s.mu.Unlock()
	if token == "" {
		return nil, errors.New("no token configured")
	}
	password := strings.TrimSpace(body.Password)
	generated := password == ""
	if generated {
		var err error
		if password, err = GeneratePassword(); err != nil {
			return nil, err
		}
	}
	code, err := CreateInvite(token, guildID, password)
	if err != nil {
		return nil, err
	}
	return map[string]any{"code": code, "password": password, "generated": generated, "rating": RatePassword(password)}, nil
}

func (s *server) handleInviteRate(r *http.Request) (any, error) {
	var body struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		return nil, err
	}
	return RatePassword(body.Password), nil
}

// handleInviteRedeem stores the token from an invite code like a token entered by hand.
func (s *server) handleInviteRedeem(r *http.Request) (any, error) {
	if r.Method != http.MethodPost {
		return nil, errors.New("method not allowed")
	}
	var body struct {
		Code     string `json:"code"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		return nil, err
	}
	inv, err := RedeemInvite(body.Code, body.Password)
	if err != nil {
		return nil, err
	}
	if _, err := NewClient(inv.Token).Me(); err != nil {
		return nil, err
	}
	if err := saveToken(inv.Token); err != nil {
		return nil, fmt.Errorf("token is valid but could not be saved: %w", err)
	}
	s.mu.Lock()
	s.token = inv.Token
	s.cfg.FromInvite = true
	if inv.GuildID != "" {
		s.cfg.GuildID = inv.GuildID
	}
	cfg := s.cfg
	s.mu.Unlock()
	_ = saveConfig(cfg)
	return map[string]bool{"ok": true}, nil
}

func (s *server) handlePing(r *http.Request) (any, error) {
	return map[string]bool{"ok": true}, nil
}

func (s *server) handleQuit(r *http.Request) (any, error) {
	s.stop()
	go func() {
		time.Sleep(500 * time.Millisecond)
		os.Exit(0)
	}()
	return map[string]bool{"ok": true}, nil
}
