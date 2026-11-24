// Peasant (The Guild Registrar) - settings stored in the user config directory.
package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Config struct {
	GuildID     string `json:"guildId"`
	IncludeBots bool   `json:"includeBots"`
	AppID       string `json:"appId"`
}

func configDir() (string, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	dir := filepath.Join(base, "TheGuildRegistrar")
	return dir, os.MkdirAll(dir, 0o700)
}

func loadConfig() Config {
	var c Config
	dir, err := configDir()
	if err != nil {
		return c
	}
	data, err := os.ReadFile(filepath.Join(dir, "config.json"))
	if err == nil {
		_ = json.Unmarshal(data, &c)
	}
	return c
}

func saveConfig(c Config) error {
	dir, err := configDir()
	if err != nil {
		return err
	}
	data, _ := json.MarshalIndent(c, "", "  ")
	return os.WriteFile(filepath.Join(dir, "config.json"), data, 0o600)
}

// removeLegacyExport deletes "last-export.txt" written by version 0.1.0. Exports are no longer
// stored on disk; they only live in the browser page until Peasant is closed.
func removeLegacyExport() {
	dir, err := configDir()
	if err != nil {
		return
	}
	_ = os.Remove(filepath.Join(dir, "last-export.txt"))
}
