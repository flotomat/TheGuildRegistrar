//go:build windows

// Peasant (The Guild Registrar) - token storage on Windows: encrypted with DPAPI (only the current Windows user can decrypt).
package main

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	crypt32           = syscall.NewLazyDLL("crypt32.dll")
	kernel32          = syscall.NewLazyDLL("kernel32.dll")
	procProtectData   = crypt32.NewProc("CryptProtectData")
	procUnprotectData = crypt32.NewProc("CryptUnprotectData")
	procLocalFree     = kernel32.NewProc("LocalFree")
)

type dataBlob struct {
	cbData uint32
	pbData *byte
}

func newBlob(d []byte) *dataBlob {
	if len(d) == 0 {
		return &dataBlob{}
	}
	return &dataBlob{cbData: uint32(len(d)), pbData: &d[0]}
}

func (b *dataBlob) bytes() []byte {
	out := make([]byte, b.cbData)
	copy(out, unsafe.Slice(b.pbData, b.cbData))
	return out
}

const cryptprotectUIForbidden = 0x1

func dpapi(proc *syscall.LazyProc, in []byte) ([]byte, error) {
	var out dataBlob
	r, _, err := proc.Call(uintptr(unsafe.Pointer(newBlob(in))), 0, 0, 0, 0, cryptprotectUIForbidden, uintptr(unsafe.Pointer(&out)))
	if r == 0 {
		return nil, err
	}
	defer procLocalFree.Call(uintptr(unsafe.Pointer(out.pbData)))
	return out.bytes(), nil
}

func tokenPath() (string, error) {
	dir, err := configDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "token.dpapi"), nil
}

func saveToken(token string) error {
	enc, err := dpapi(procProtectData, []byte(token))
	if err != nil {
		return err
	}
	p, err := tokenPath()
	if err != nil {
		return err
	}
	return os.WriteFile(p, enc, 0o600)
}

func loadToken() (string, error) {
	p, err := tokenPath()
	if err != nil {
		return "", err
	}
	enc, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	dec, err := dpapi(procUnprotectData, enc)
	if err != nil {
		return "", err
	}
	return string(dec), nil
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

const tokenStorageInfo = "Windows DPAPI (encrypted for your Windows user)"
