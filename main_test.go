package main

import "testing"

func TestSanitizeChirp(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "lowercase replacement",
			input: "I need a kerfuffle",
			want:  "I need a ****",
		},
		{
			name:  "uppercase replacement",
			input: "FORNAX is loud",
			want:  "**** is loud",
		},
		{
			name:  "mixed case sharbert",
			input: "I saw a Sharbert on TV",
			want:  "I saw a **** on TV",
		},
		{
			name:  "punctuation untouched",
			input: "Sharbert! is allowed",
			want:  "Sharbert! is allowed",
		},
		{
			name:  "whitespace preserved",
			input: "kerfuffle  sharbert\nFornax",
			want:  "****  ****\n****",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := sanitizeChirp(tt.input); got != tt.want {
				t.Errorf("sanitizeChirp() = %q, want %q", got, tt.want)
			}
		})
	}
}
