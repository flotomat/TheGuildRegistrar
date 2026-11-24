//go:build darwin

// The Guild Registrar Companion - token storage on macOS: login keychain via the "security" tool.
package main

import (
	"os/exec"
	"strings"
)

const keychainService = "TheGuildRegistrar"
const keychainAccount = "discord-bot-token"

func saveToken(token string) error {
	return exec.Command("security", "add-generic-password", "-U", "-a", keychainAccount, "-s", keychainService, "-w", token).Run()
}

func loadToken() (string, error) {
	out, err := exec.Command("security", "find-generic-password", "-a", keychainAccount, "-s", keychainService, "-w").Output()
	if err != nil {
		// not found
		return "", nil
	}
	return strings.TrimSpace(string(out)), nil
}

func deleteToken() error {
	_ = exec.Command("security", "delete-generic-password", "-a", keychainAccount, "-s", keychainService).Run()
	return nil
}

const tokenStorageInfo = "macOS keychain"
