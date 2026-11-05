package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadMissingFile(t *testing.T) {
	c, err := Load(filepath.Join(t.TempDir(), "nope.json"))
	if err != nil {
		t.Fatal(err)
	}
	if c.FullName != "" || len(c.Sites) != 0 {
		t.Errorf("expected empty config, got %+v", c)
	}
}

func TestLoad(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	data := `{"FULL_NAME": "Robert", "sites": [{"name": "github.com", "counter": 3, "type": "PIN"}]}`
	if err := os.WriteFile(path, []byte(data), 0o600); err != nil {
		t.Fatal(err)
	}

	c, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if c.FullName != "Robert" {
		t.Errorf("FullName = %q", c.FullName)
	}
	if s, ok := c.Site("github.com"); !ok || s.Counter != 3 || s.Type != "PIN" {
		t.Errorf("Site(github.com) = %+v, %v", s, ok)
	}
	if _, ok := c.Site("gitlab.com"); ok {
		t.Error("unexpected site gitlab.com")
	}
}

func TestPath(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv(PathEnv, "")
	if got, want := Path(), "/home/u/.config/mpw/config.json"; got != want {
		t.Errorf("default: got %q, want %q", got, want)
	}

	t.Setenv("XDG_CONFIG_HOME", "/xdg")
	if got, want := Path(), "/xdg/config.json"; got != want {
		t.Errorf("XDG: got %q, want %q", got, want)
	}

	t.Setenv(PathEnv, "/icloud/config.json")
	if got, want := Path(), "/icloud/config.json"; got != want {
		t.Errorf("MPW_CONFIG: got %q, want %q", got, want)
	}
}

func TestLoadInvalidJSON(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(path); err == nil {
		t.Error("expected error for invalid JSON")
	}
}
