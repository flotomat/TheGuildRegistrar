// The Guild Registrar Companion - build the import text for the addon (format TGR1, see docs/import-format.md).
package main

import (
	"strings"
	"time"
)

type ExportOptions struct {
	IncludeBots         bool
	IncludeManagedRoles bool
}

type ExportResult struct {
	Text    string `json:"text"`
	Members int    `json:"members"`
	Roles   int    `json:"roles"`
	Skipped int    `json:"skipped"`
	Server  string `json:"server"`
}

var escaper = strings.NewReplacer(`\`, `\\`, `;`, `\;`, `,`, `\,`, "\r", " ", "\n", " ")

func esc(s string) string {
	return escaper.Replace(strings.TrimSpace(s))
}

// BuildExport creates the TGR1 text. Only display names and role names are exported - no IDs.
func BuildExport(guild *Guild, roles []Role, members []Member, opt ExportOptions, now time.Time) ExportResult {
	var b strings.Builder
	b.WriteString("#TGR1;")
	b.WriteString(now.UTC().Format("2006-01-02T15:04:05Z"))
	b.WriteString(";")
	b.WriteString(esc(guild.Name))
	b.WriteString("\n")

	roleName := map[string]string{}
	var roleNames []string
	for _, r := range roles {
		if r.Managed && !opt.IncludeManagedRoles {
			continue
		}
		roleName[r.ID] = r.Name
		roleNames = append(roleNames, esc(r.Name))
	}
	b.WriteString("@roles;")
	b.WriteString(strings.Join(roleNames, ","))
	b.WriteString("\n")

	// role order (highest first) for each member
	pos := map[string]int{}
	for i, r := range roles {
		pos[r.ID] = i
	}

	res := ExportResult{Roles: len(roleNames), Server: guild.Name}
	for _, m := range members {
		if m.User.Bot && !opt.IncludeBots {
			res.Skipped++
			continue
		}
		name := esc(m.DisplayName())
		if name == "" {
			res.Skipped++
			continue
		}
		ids := append([]string(nil), m.Roles...)
		sortByPos(ids, pos)
		var mr []string
		for _, id := range ids {
			if n, ok := roleName[id]; ok {
				mr = append(mr, esc(n))
			}
		}
		b.WriteString(name)
		b.WriteString(";")
		b.WriteString(strings.Join(mr, ","))
		b.WriteString("\n")
		res.Members++
	}
	res.Text = b.String()
	return res
}

func sortByPos(ids []string, pos map[string]int) {
	get := func(id string) int {
		if p, ok := pos[id]; ok {
			return p
		}
		return 1 << 30
	}
	for i := 1; i < len(ids); i++ {
		for j := i; j > 0 && get(ids[j]) < get(ids[j-1]); j-- {
			ids[j], ids[j-1] = ids[j-1], ids[j]
		}
	}
}
