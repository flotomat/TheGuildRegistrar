// The Guild Registrar Companion
//
// Exports the display names and role names of a Discord server's members for the WoW addon
// "The Guild Registrar". Uses your own Discord bot (read-only, no permissions needed).
//
// Usage:
//
//	tgr-companion                      start the local web interface (opens your browser)
//	tgr-companion -no-browser          start it, but only print the address
//	tgr-companion export [-guild ID] [-out FILE] [-include-bots]
//	                                   export without interface (token from the saved setup or TGR_BOT_TOKEN)
//	tgr-companion -version
//
// Copyright (C) 2026 Flotomat - GPL-3.0-or-later
package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"time"
)

// version is set at build time: -ldflags "-X main.version=v1.2.3"
var version = "dev"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "export" {
		os.Exit(runExportCLI(os.Args[2:]))
	}

	noBrowser := flag.Bool("no-browser", false, "do not open the browser automatically")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()
	if *showVersion {
		fmt.Println("The Guild Registrar Companion", version)
		return
	}
	if err := runServer(!*noBrowser); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		waitBeforeExit()
		os.Exit(1)
	}
}

func runExportCLI(args []string) int {
	fs := flag.NewFlagSet("export", flag.ExitOnError)
	guildID := fs.String("guild", "", "Discord server (guild) ID; default: the one selected in the interface")
	out := fs.String("out", "", "write to this file instead of standard output")
	includeBots := fs.Bool("include-bots", false, "also export bot accounts")
	_ = fs.Parse(args)

	token := os.Getenv("TGR_BOT_TOKEN")
	if token == "" {
		t, err := loadToken()
		if err != nil {
			fmt.Fprintln(os.Stderr, "Could not read saved token:", err)
			return 1
		}
		token = t
	}
	if token == "" {
		fmt.Fprintln(os.Stderr, "No bot token. Run the companion once without arguments to set it up, or set TGR_BOT_TOKEN.")
		return 1
	}
	cfg := loadConfig()
	if *guildID == "" {
		*guildID = cfg.GuildID
	}
	client := NewClient(token)
	if *guildID == "" {
		guilds, err := client.Guilds()
		if err != nil {
			fmt.Fprintln(os.Stderr, "Error:", err)
			return 1
		}
		if len(guilds) != 1 {
			fmt.Fprintln(os.Stderr, "The bot is on several (or no) servers - choose one with -guild:")
			for _, g := range guilds {
				fmt.Fprintf(os.Stderr, "  %s  %s\n", g.ID, g.Name)
			}
			return 1
		}
		*guildID = guilds[0].ID
	}
	res, err := doExport(client, *guildID, ExportOptions{IncludeBots: *includeBots || cfg.IncludeBots}, nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", describeError(err))
		return 1
	}
	if *out != "" {
		if err := os.WriteFile(*out, []byte(res.Text), 0o600); err != nil {
			fmt.Fprintln(os.Stderr, "Error:", err)
			return 1
		}
		fmt.Fprintf(os.Stderr, "Exported %d members and %d roles of %q to %s\n", res.Members, res.Roles, res.Server, *out)
		return 0
	}
	fmt.Print(res.Text)
	return 0
}

func doExport(client *Client, guildID string, opt ExportOptions, progress func(int)) (ExportResult, error) {
	guild, err := client.Guild(guildID)
	if err != nil {
		return ExportResult{}, err
	}
	roles, err := client.Roles(guildID)
	if err != nil {
		return ExportResult{}, err
	}
	members, err := client.Members(guildID, progress)
	if err != nil {
		return ExportResult{}, err
	}
	return BuildExport(guild, roles, members, opt, time.Now()), nil
}

func describeError(err error) string {
	switch {
	case errors.Is(err, ErrInvalidToken):
		return "the bot token is invalid (reset it in the Developer Portal and enter it again)"
	case errors.Is(err, ErrMissingIntent):
		return "the bot may not read the member list: enable \"Server Members Intent\" on the Bot page of the Developer Portal"
	}
	var apiErr *APIError
	if errors.As(err, &apiErr) && apiErr.Status == 404 {
		return "server not found - is the bot invited to this server?"
	}
	return err.Error()
}

func waitBeforeExit() {
	fmt.Fprintln(os.Stderr, "Press Enter to close.")
	_, _ = fmt.Scanln()
}
