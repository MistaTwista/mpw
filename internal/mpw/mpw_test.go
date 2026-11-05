package mpw

import (
	"encoding/json"
	"os"
	"testing"
)

const testMasterPassword = "banana colored duckling"

// golden holds regression vectors captured from github.com/belogron/mpw, an
// independent Go implementation. They add non-ASCII names and sites and more
// counters to the reference vectors in testdata/testcases.xml. The iOS app
// tests read the same file.
type golden struct {
	MasterPassword string `json:"masterPassword"`
	Passwords      []struct {
		FullName string     `json:"fullName"`
		SiteName string     `json:"siteName"`
		Counter  uint32     `json:"counter"`
		Type     ResultType `json:"type"`
		Result   string     `json:"result"`
	} `json:"passwords"`
	Identicons []struct {
		FullName string `json:"fullName"`
		Text     string `json:"text"`
		Color    int    `json:"color"`
	} `json:"identicons"`
}

func loadGolden(t *testing.T) golden {
	t.Helper()
	data, err := os.ReadFile("testdata/golden.json")
	if err != nil {
		t.Fatal(err)
	}
	var g golden
	if err := json.Unmarshal(data, &g); err != nil {
		t.Fatal(err)
	}
	if len(g.Passwords) == 0 || len(g.Identicons) == 0 {
		t.Fatal("golden.json has no vectors")
	}
	return g
}

func TestSitePassword(t *testing.T) {
	g := loadGolden(t)
	masterKeys := map[string][]byte{}
	for _, v := range g.Passwords {
		mk, ok := masterKeys[v.FullName]
		if !ok {
			var err error
			mk, err = MasterKey(v.FullName, g.MasterPassword)
			if err != nil {
				t.Fatal(err)
			}
			masterKeys[v.FullName] = mk
		}

		got, err := SitePassword(SiteKey(mk, v.SiteName, v.Counter), v.Type)
		if err != nil {
			t.Fatalf("%+v: %v", v, err)
		}
		if got != v.Result {
			t.Errorf("%s / %s / %d / %s: got %q, want %q", v.FullName, v.SiteName, v.Counter, v.Type, got, v.Result)
		}
	}
}

func TestPassword(t *testing.T) {
	got, err := Password("Robert Lee Mitchell", testMasterPassword, "masterpasswordapp.com", 1, Long)
	if err != nil {
		t.Fatal(err)
	}
	if want := "Jejr5[RepuSosp"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestSitePasswordUnknownType(t *testing.T) {
	if _, err := SitePassword(make([]byte, 32), "Nope"); err == nil {
		t.Error("expected error for unknown result type")
	}
}

func TestNewIdenticon(t *testing.T) {
	g := loadGolden(t)
	for _, v := range g.Identicons {
		want := Identicon{Text: v.Text, Color: v.Color}
		if got := NewIdenticon(v.FullName, g.MasterPassword); got != want {
			t.Errorf("%s: got %+v, want %+v", v.FullName, got, want)
		}
	}
}

func TestIdenticonKeepsAllAccessories(t *testing.T) {
	for i, a := range accessories {
		if a == "" {
			t.Errorf("accessory %d is empty", i)
		}
	}
}

func TestParseResultType(t *testing.T) {
	for in, want := range map[string]ResultType{
		"x": Maximum, "Long": Long, "long": Long, "L": Long, "pin": PIN, "i": PIN, "Phrase": Phrase,
	} {
		got, err := ParseResultType(in)
		if err != nil || got != want {
			t.Errorf("ParseResultType(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	if _, err := ParseResultType("q"); err == nil {
		t.Error("expected error for unknown type")
	}
}

func TestEveryTypeHasTemplates(t *testing.T) {
	for _, rt := range ResultTypes {
		tpls, ok := templates[rt.Type]
		if !ok || len(tpls) == 0 {
			t.Errorf("%s: no templates", rt.Type)
		}
		for _, tpl := range tpls {
			for _, c := range tpl {
				if _, ok := templateChars[c]; !ok {
					t.Errorf("%s: template %q uses unknown class %q", rt.Type, tpl, c)
				}
			}
		}
	}
}
