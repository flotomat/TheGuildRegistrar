//go:build !windows && !darwin

// Peasant (The Guild Registrar) - token storage on Linux and others: file readable only by the current user.
package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

func tokenPath() (string, error) {
	dir, err := configDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "token"), nil
}

func saveToken(token string) error {
	p, err := tokenPath()
	if err != nil {
		return err
	}
	return os.WriteFile(p, []byte(token), 0o600)
}

func loadToken() (string, error) {
	p, err := tokenPath()
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	return strings.TrimSpace(string(data)), err
}

func deleteToken() error {
	p, err := tokenPath()
	if err != nil {
		return err
	}
	err = os.Remove(p)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

const tokenStorageInfo = "file with permissions 0600 in your config directory"
