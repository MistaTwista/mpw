package mpw

import (
	"encoding/xml"
	"os"
	"testing"
)

// testCase is one <case> of testdata/testcases.xml, the test vectors of the
// reference Master Password implementation. Empty fields are inherited from
// the case named in Parent.
type testCase struct {
	ID             string `xml:"id,attr"`
	Parent         string `xml:"parent,attr"`
	Algorithm      int    `xml:"algorithm"`
	FullName       string `xml:"fullName"`
	MasterPassword string `xml:"masterPassword"`
	SiteName       string `xml:"siteName"`
	SiteCounter    uint32 `xml:"siteCounter"`
	ResultType     string `xml:"resultType"`
	KeyPurpose     string `xml:"keyPurpose"`
	KeyContext     string `xml:"keyContext"`
	Result         string `xml:"result"`
	Identicon      string `xml:"identicon"`
}

func (c *testCase) inherit(p testCase) {
	fill := func(dst *string, src string) {
		if *dst == "" {
			*dst = src
		}
	}
	if c.Algorithm == 0 {
		c.Algorithm = p.Algorithm
	}
	if c.SiteCounter == 0 {
		c.SiteCounter = p.SiteCounter
	}
	fill(&c.FullName, p.FullName)
	fill(&c.MasterPassword, p.MasterPassword)
	fill(&c.SiteName, p.SiteName)
	fill(&c.ResultType, p.ResultType)
	fill(&c.KeyPurpose, p.KeyPurpose)
	fill(&c.KeyContext, p.KeyContext)
	fill(&c.Result, p.Result)
	fill(&c.Identicon, p.Identicon)
}

func loadTestCases(t *testing.T) []testCase {
	t.Helper()
	data, err := os.ReadFile("testdata/testcases.xml")
	if err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Cases []testCase `xml:"case"`
	}
	if err := xml.Unmarshal(data, &doc); err != nil {
		t.Fatal(err)
	}

	// Parents always precede their children in the file.
	resolved := make(map[string]testCase, len(doc.Cases))
	for i, c := range doc.Cases {
		if _, dup := resolved[c.ID]; dup {
			t.Fatalf("duplicate case %q", c.ID)
		}
		if c.Parent != "" {
			p, ok := resolved[c.Parent]
			if !ok {
				t.Fatalf("case %q: unknown parent %q", c.ID, c.Parent)
			}
			c.inherit(p)
		}
		resolved[c.ID] = c
		doc.Cases[i] = c
	}
	return doc.Cases
}

// TestReferenceVectors checks algorithm v3 site passwords for login
// (Authentication) against the reference implementation. Login names,
// recovery answers and older algorithm versions are not supported.
func TestReferenceVectors(t *testing.T) {
	masterKeys := map[[2]string][]byte{}
	checked := 0
	for _, c := range loadTestCases(t) {
		if c.Algorithm != 3 || c.KeyPurpose != "Authentication" || c.KeyContext != "" {
			continue
		}
		t.Run(c.ID, func(t *testing.T) {
			id := [2]string{c.FullName, c.MasterPassword}
			mk, ok := masterKeys[id]
			if !ok {
				var err error
				if mk, err = MasterKey(c.FullName, c.MasterPassword); err != nil {
					t.Fatal(err)
				}
				masterKeys[id] = mk
			}

			got, err := SitePassword(SiteKey(mk, c.SiteName, c.SiteCounter), ResultType(c.ResultType))
			if err != nil {
				t.Fatal(err)
			}
			if got != c.Result {
				t.Errorf("password = %q, want %q", got, c.Result)
			}
			if icon := NewIdenticon(c.FullName, c.MasterPassword).Text; icon != c.Identicon {
				t.Errorf("identicon = %q, want %q", icon, c.Identicon)
			}
		})
		checked++
	}
	if checked == 0 {
		t.Fatal("no reference vectors checked")
	}
	t.Logf("checked %d reference vectors", checked)
}
