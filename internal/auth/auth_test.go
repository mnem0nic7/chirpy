package auth

import (
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestHashPasswordAndCheck(t *testing.T) {
	password := "supersafe"
	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if hash == password {
		t.Fatalf("HashPassword() returned plaintext")
	}

	match, err := CheckPasswordHash(password, hash)
	if err != nil {
		t.Fatalf("CheckPasswordHash() error = %v", err)
	}
	if !match {
		t.Fatalf("expected password to match hash")
	}

	match, err = CheckPasswordHash("wrong", hash)
	if err != nil {
		t.Fatalf("CheckPasswordHash() error for wrong password = %v", err)
	}
	if match {
		t.Fatalf("expected mismatch for wrong password")
	}
}

func TestMakeAndValidateJWT(t *testing.T) {
	userID := uuid.New()
	secret := "test-secret"

	token, err := MakeJWT(userID, secret, time.Minute)
	if err != nil {
		t.Fatalf("MakeJWT() error = %v", err)
	}

	validatedID, err := ValidateJWT(token, secret)
	if err != nil {
		t.Fatalf("ValidateJWT() error = %v", err)
	}

	if validatedID != userID {
		t.Fatalf("ValidateJWT() returned %s, want %s", validatedID, userID)
	}
}

func TestValidateJWTExpired(t *testing.T) {
	userID := uuid.New()
	secret := "test-secret"

	token, err := MakeJWT(userID, secret, -time.Minute)
	if err != nil {
		t.Fatalf("MakeJWT() error = %v", err)
	}

	if _, err := ValidateJWT(token, secret); err == nil {
		t.Fatalf("ValidateJWT() expected error for expired token")
	}
}

func TestValidateJWTWrongSecret(t *testing.T) {
	userID := uuid.New()
	secret := "test-secret"
	token, err := MakeJWT(userID, secret, time.Minute)
	if err != nil {
		t.Fatalf("MakeJWT() error = %v", err)
	}

	if _, err := ValidateJWT(token, "wrong-secret"); err == nil {
		t.Fatalf("ValidateJWT() expected error for wrong secret")
	}
}

func TestMakeRefreshToken(t *testing.T) {
	seen := make(map[string]struct{})
	for i := 0; i < 5; i++ {
		token, err := MakeRefreshToken()
		if err != nil {
			t.Fatalf("MakeRefreshToken() error = %v", err)
		}

		if len(token) != 64 {
			t.Fatalf("MakeRefreshToken() length = %d, want 64", len(token))
		}

		if _, exists := seen[token]; exists {
			t.Fatalf("MakeRefreshToken() produced duplicate token %s", token)
		}
		seen[token] = struct{}{}
	}
}

func TestGetBearerToken(t *testing.T) {
	headers := http.Header{}
	headers.Set("Authorization", "Bearer   abc123")

	token, err := GetBearerToken(headers)
	if err != nil {
		t.Fatalf("GetBearerToken() error = %v", err)
	}

	if token != "abc123" {
		t.Fatalf("GetBearerToken() = %q, want %q", token, "abc123")
	}
}

func TestGetBearerTokenErrors(t *testing.T) {
	cases := []struct {
		name    string
		headers http.Header
	}{
		{
			name:    "missing header",
			headers: http.Header{},
		},
		{
			name: "wrong prefix",
			headers: http.Header{
				"Authorization": []string{"Token abc"},
			},
		},
		{
			name: "empty token",
			headers: http.Header{
				"Authorization": []string{"Bearer   "},
			},
		},
	}

	for _, tc := range cases {
		if _, err := GetBearerToken(tc.headers); err == nil {
			t.Fatalf("GetBearerToken() expected error for case %q", tc.name)
		}
	}
}

func TestGetAPIKey(t *testing.T) {
	headers := http.Header{}
	headers.Set("Authorization", "ApiKey   secret-value")

	key, err := GetAPIKey(headers)
	if err != nil {
		t.Fatalf("GetAPIKey() error = %v", err)
	}

	if key != "secret-value" {
		t.Fatalf("GetAPIKey() = %q, want %q", key, "secret-value")
	}
}

func TestGetAPIKeyErrors(t *testing.T) {
	cases := []struct {
		name    string
		headers http.Header
	}{
		{
			name:    "missing header",
			headers: http.Header{},
		},
		{
			name: "wrong prefix",
			headers: http.Header{
				"Authorization": []string{"Bearer abc"},
			},
		},
		{
			name: "empty key",
			headers: http.Header{
				"Authorization": []string{"ApiKey   "},
			},
		},
	}

	for _, tc := range cases {
		if _, err := GetAPIKey(tc.headers); err == nil {
			t.Fatalf("GetAPIKey() expected error for case %q", tc.name)
		}
	}
}
