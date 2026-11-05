package main

import (
	"io"
	"testing"

	"github.com/MistaTwista/mpw/internal/config"
	"github.com/MistaTwista/mpw/internal/mpw"
)

func parse(t *testing.T, args ...string) flags {
	t.Helper()
	f, err := parseFlags(args, io.Discard)
	if err != nil {
		t.Fatalf("parseFlags(%q): %v", args, err)
	}
	return f
}

func TestParseFlagsDefaults(t *testing.T) {
	f := parse(t)
	if f.counterSet || f.counter != 1 || f.resultType != mpw.Long || f.site != "" {
		t.Errorf("unexpected defaults: %+v", f)
	}
}

func TestParseFlagsShortAndLongShareValue(t *testing.T) {
	// The last occurrence wins, even when it equals the default.
	f := parse(t, "--counter", "3", "-c", "1", "-t", "x", "--site-result-type", "long", "github.com")
	if !f.counterSet || f.counter != 1 {
		t.Errorf("counter = %d (set %v), want 1 (set true)", f.counter, f.counterSet)
	}
	if f.resultType != mpw.Long {
		t.Errorf("resultType = %q, want Long", f.resultType)
	}
	if f.site != "github.com" {
		t.Errorf("site = %q", f.site)
	}
}

func TestParseFlagsErrors(t *testing.T) {
	for _, args := range [][]string{
		{"-t", "q"},
		{"-c", "0"},
		{"-c", "4294967296"},
		{"a.com", "b.com"},
	} {
		if _, err := parseFlags(args, io.Discard); err == nil {
			t.Errorf("parseFlags(%q): expected error", args)
		}
	}
}

func TestResolveFullName(t *testing.T) {
	cfg := config.Config{FullName: "from config"}
	env := func(v string) func(string) string {
		return func(string) string { return v }
	}

	tests := []struct {
		name string
		flag string
		env  string
		cfg  config.Config
		want string
	}{
		{"cli wins", "from cli", "from env", cfg, "from cli"},
		{"env over config", "", "from env", cfg, "from env"},
		{"config", "", "", cfg, "from config"},
		{"nothing: ask", "", "", config.Config{}, ""},
	}
	for _, tt := range tests {
		if got := resolveFullName(flags{fullName: tt.flag}, tt.cfg, env(tt.env)); got != tt.want {
			t.Errorf("%s: got %q, want %q", tt.name, got, tt.want)
		}
	}
}

func TestResolveCounter(t *testing.T) {
	cfg := config.Config{Sites: []config.Site{
		{Name: "github.com", Counter: 5},
		{Name: "no-counter.com"},
	}}

	tests := []struct {
		name string
		f    flags
		site string
		want uint32
	}{
		{"cli over config", flags{counter: 2, counterSet: true}, "github.com", 2},
		{"explicit default over config", flags{counter: 1, counterSet: true}, "github.com", 1},
		{"config", flags{counter: 1}, "github.com", 5},
		{"config without counter", flags{counter: 1}, "no-counter.com", 1},
		{"unknown site", flags{counter: 1}, "gitlab.com", 1},
	}
	for _, tt := range tests {
		if got := resolveCounter(tt.f, cfg, tt.site); got != tt.want {
			t.Errorf("%s: got %d, want %d", tt.name, got, tt.want)
		}
	}
}
