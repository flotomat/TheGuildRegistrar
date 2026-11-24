package main

import (
	"strings"
	"testing"
	"time"
)

func strp(s string) *string { return &s }

func TestBuildExport(t *testing.T) {
	guild := &Guild{ID: "1", Name: "My;Server"}
	roles := []Role{
		{ID: "10", Name: "Officer", Position: 5},
		{ID: "11", Name: "Raider, Core", Position: 3},
		{ID: "12", Name: "BotRole", Position: 4, Managed: true},
	}
	members := []Member{
		{User: User{ID: "100", Username: "jens", GlobalName: strp("Jens")}, Nick: strp("Jens | Wurstinator"), Roles: []string{"11", "10"}},
		{User: User{ID: "101", Username: "anna", GlobalName: strp("Anna")}, Roles: []string{"11"}},
		{User: User{ID: "102", Username: "plainuser"}},
		{User: User{ID: "103", Username: "somebot", Bot: true}, Roles: []string{"12"}},
	}
	res := BuildExport(guild, roles, members, ExportOptions{}, time.Date(2026, 11, 24, 20, 0, 0, 0, time.UTC))
	want := strings.Join([]string{
		`#TGR1;2026-11-24T20:00:00Z;My\;Server`,
		`@roles;Officer,Raider\, Core`,
		`Jens | Wurstinator;Officer,Raider\, Core`,
		`Anna;Raider\, Core`,
		`plainuser;`,
		``,
	}, "\n")
	if res.Text != want {
		t.Fatalf("unexpected export:\n%s\nwant:\n%s", res.Text, want)
	}
	if res.Members != 3 || res.Skipped != 1 || res.Roles != 2 {
		t.Fatalf("unexpected counts: %+v", res)
	}
}
