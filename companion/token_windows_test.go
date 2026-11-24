//go:build windows

package main

import "testing"

func TestDPAPIRoundTrip(t *testing.T) {
	enc, err := dpapi(procProtectData, []byte("secret-token"))
	if err != nil {
		t.Fatal(err)
	}
	if string(enc) == "secret-token" {
		t.Fatal("data was not encrypted")
	}
	dec, err := dpapi(procUnprotectData, enc)
	if err != nil {
		t.Fatal(err)
	}
	if string(dec) != "secret-token" {
		t.Fatalf("got %q", dec)
	}
}
