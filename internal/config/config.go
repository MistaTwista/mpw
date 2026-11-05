// Package config reads the optional mpw JSON config:
//
//	{
//	  "FULL_NAME": "Robert Lee Mitchell",
//	  "sites": [{"name": "github.com", "counter": 2, "type": "Long"}]
//	}
//
// The iOS app reads and writes the same file and keeps keys it does not know.
package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

type Site struct {
	Name    string `json:"name"`
	Counter uint32 `json:"counter"`
	// Type is a result type name such as "Long". Empty means the default.
	Type string `json:"type,omitempty"`
}

type Config struct {
	FullName string `json:"FULL_NAME"`
	Sites    []Site `json:"sites"`
}

// Site returns the settings stored for the named site.
func (c Config) Site(name string) (Site, bool) {
	for _, s := range c.Sites {
		if s.Name == name {
			return s, true
		}
	}
	return Site{}, false
}

// PathEnv names the environment variable with an explicit config path.
const PathEnv = "MPW_CONFIG"

// Path is $MPW_CONFIG when set, then $XDG_CONFIG_HOME/config.json when
// XDG_CONFIG_HOME is set, otherwise ~/.config/mpw/config.json.
func Path() string {
	if p := os.Getenv(PathEnv); p != "" {
		return p
	}
	if dir := os.Getenv("XDG_CONFIG_HOME"); dir != "" {
		return filepath.Join(dir, "config.json")
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "mpw", "config.json")
}

// Load reads the config at path. A missing file yields an empty config.
func Load(path string) (Config, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Config{}, nil
	}
	if err != nil {
		return Config{}, err
	}

	var c Config
	if err := json.Unmarshal(b, &c); err != nil {
		return Config{}, fmt.Errorf("parse %s: %w", path, err)
	}
	return c, nil
}
