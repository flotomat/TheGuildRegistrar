// Peasant (The Guild Registrar) - minimal Discord REST client (bot token, read-only).
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"time"
)

const apiBase = "https://discord.com/api/v10"

// Application flags that tell whether the privileged "Server Members Intent" is enabled.
const (
	flagGatewayGuildMembers        = 1 << 14
	flagGatewayGuildMembersLimited = 1 << 15
)

// APIError is a Discord error response.
type APIError struct {
	Status  int
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *APIError) Error() string {
	return fmt.Sprintf("Discord API error %d (code %d): %s", e.Status, e.Code, e.Message)
}

// ErrInvalidToken is returned for HTTP 401.
var ErrInvalidToken = errors.New("invalid bot token")

// ErrMissingIntent is returned when the member list cannot be read (Server Members Intent off).
var ErrMissingIntent = errors.New("server members intent missing")

type Client struct {
	token string
	http  *http.Client
}

func NewClient(token string) *Client {
	return &Client{token: token, http: &http.Client{Timeout: 30 * time.Second}}
}

func (c *Client) get(path string, out any) error {
	for attempt := 0; attempt < 6; attempt++ {
		req, err := http.NewRequest(http.MethodGet, apiBase+path, nil)
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bot "+c.token)
		req.Header.Set("User-Agent", "DiscordBot (https://github.com/Flotomat/TheGuildRegistrar, "+version+")")
		resp, err := c.http.Do(req)
		if err != nil {
			return err
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return err
		}

		// respect rate limits
		if resp.StatusCode == http.StatusTooManyRequests {
			var rl struct {
				RetryAfter float64 `json:"retry_after"`
			}
			_ = json.Unmarshal(body, &rl)
			wait := time.Duration(rl.RetryAfter*1000) * time.Millisecond
			if wait <= 0 {
				wait = time.Second
			}
			time.Sleep(wait)
			continue
		}
		if resp.Header.Get("X-RateLimit-Remaining") == "0" {
			if s, err := strconv.ParseFloat(resp.Header.Get("X-RateLimit-Reset-After"), 64); err == nil && s > 0 {
				defer time.Sleep(time.Duration(s*1000) * time.Millisecond)
			}
		}

		if resp.StatusCode == http.StatusUnauthorized {
			return ErrInvalidToken
		}
		if resp.StatusCode >= 400 {
			apiErr := &APIError{Status: resp.StatusCode}
			_ = json.Unmarshal(body, apiErr)
			return apiErr
		}
		return json.Unmarshal(body, out)
	}
	return errors.New("Discord rate limit: too many retries")
}

type User struct {
	ID         string  `json:"id"`
	Username   string  `json:"username"`
	GlobalName *string `json:"global_name"`
	Bot        bool    `json:"bot"`
}

type Application struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Flags int64  `json:"flags"`
}

func (a *Application) MembersIntent() bool {
	return a.Flags&(flagGatewayGuildMembers|flagGatewayGuildMembersLimited) != 0
}

type Guild struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type Role struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Position int    `json:"position"`
	Managed  bool   `json:"managed"`
}

type Member struct {
	User  User     `json:"user"`
	Nick  *string  `json:"nick"`
	Roles []string `json:"roles"`
}

// DisplayName follows Discord: server nickname, then global display name, then user name.
func (m *Member) DisplayName() string {
	if m.Nick != nil && *m.Nick != "" {
		return *m.Nick
	}
	if m.User.GlobalName != nil && *m.User.GlobalName != "" {
		return *m.User.GlobalName
	}
	return m.User.Username
}

func (c *Client) Me() (*User, error) {
	var u User
	return &u, c.get("/users/@me", &u)
}

func (c *Client) Application() (*Application, error) {
	var a Application
	return &a, c.get("/oauth2/applications/@me", &a)
}

func (c *Client) Guilds() ([]Guild, error) {
	var gs []Guild
	if err := c.get("/users/@me/guilds?limit=200", &gs); err != nil {
		return nil, err
	}
	sort.Slice(gs, func(i, j int) bool { return gs[i].Name < gs[j].Name })
	return gs, nil
}

func (c *Client) Guild(id string) (*Guild, error) {
	var g Guild
	return &g, c.get("/guilds/"+url.PathEscape(id), &g)
}

// Roles returns the roles of a guild, highest first (without @everyone).
func (c *Client) Roles(guildID string) ([]Role, error) {
	var rs []Role
	if err := c.get("/guilds/"+url.PathEscape(guildID)+"/roles", &rs); err != nil {
		return nil, err
	}
	out := rs[:0]
	for _, r := range rs {
		if r.ID != guildID {
			out = append(out, r)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Position != out[j].Position {
			return out[i].Position > out[j].Position
		}
		return out[i].ID < out[j].ID
	})
	return out, nil
}

// Members returns all members of a guild (paginated, 1000 per request).
func (c *Client) Members(guildID string, progress func(n int)) ([]Member, error) {
	var all []Member
	after := "0"
	for {
		var page []Member
		path := fmt.Sprintf("/guilds/%s/members?limit=1000&after=%s", url.PathEscape(guildID), after)
		if err := c.get(path, &page); err != nil {
			var apiErr *APIError
			if errors.As(err, &apiErr) && apiErr.Status == http.StatusForbidden {
				return nil, ErrMissingIntent
			}
			return nil, err
		}
		all = append(all, page...)
		if progress != nil {
			progress(len(all))
		}
		if len(page) < 1000 {
			return all, nil
		}
		after = page[len(page)-1].User.ID
	}
}

// InviteURL builds the bot invite link (scope bot, no permissions).
func InviteURL(appID string) string {
	return "https://discord.com/oauth2/authorize?client_id=" + url.QueryEscape(appID) + "&scope=bot&permissions=0"
}

// PortalURL links to the bot page of the application in the developer portal.
func PortalURL(appID string) string {
	if appID == "" {
		return "https://discord.com/developers/applications"
	}
	return "https://discord.com/developers/applications/" + url.PathEscape(appID) + "/bot"
}
