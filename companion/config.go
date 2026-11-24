// The Guild Registrar Companion - settings stored in the user config directory.
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

// saveExport writes the last export next to the config so it can be opened again.
func saveExport(text string) (string, error) {
	dir, err := configDir()
	if err != nil {
		return "", err
	}
	path := filepath.Join(dir, "last-export.txt")
	return path, os.WriteFile(path, []byte(text), 0o600)
}
