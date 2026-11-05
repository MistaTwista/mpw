package mpw

import (
	"fmt"
	"strings"
)

// ResultType names a family of password templates.
//
// Site administrators enforce arbitrary password policies, so the site key
// has to be rendered in a form those policies accept. Each type is a set of
// templates that keeps the output entropy as high as possible under such
// constraints.
type ResultType string

const (
	Maximum ResultType = "Maximum" // 20 characters, contains symbols.
	Long    ResultType = "Long"    // Copy-friendly, 14 characters, symbols.
	Medium  ResultType = "Medium"  // Copy-friendly, 8 characters, symbols.
	Basic   ResultType = "Basic"   // 8 characters, no symbols.
	Short   ResultType = "Short"   // Copy-friendly, 4 characters, no symbols.
	PIN     ResultType = "PIN"     // 4 numbers.
	Name    ResultType = "Name"    // 9 letter name.
	Phrase  ResultType = "Phrase"  // 20 character sentence.
)

// ResultTypes lists all types with their one-letter abbreviations, in the
// order they are presented to the user.
var ResultTypes = []struct {
	Abbr string
	Type ResultType
}{
	{"x", Maximum},
	{"l", Long},
	{"m", Medium},
	{"b", Basic},
	{"s", Short},
	{"i", PIN},
	{"n", Name},
	{"p", Phrase},
}

// ParseResultType accepts a full type name or its one-letter abbreviation,
// case-insensitively.
func ParseResultType(s string) (ResultType, error) {
	for _, rt := range ResultTypes {
		if strings.EqualFold(s, rt.Abbr) || strings.EqualFold(s, string(rt.Type)) {
			return rt.Type, nil
		}
	}
	return "", fmt.Errorf("unknown result type %q", s)
}

// templates maps each type to its templates. Every template character is a
// class from templateChars.
var templates = map[ResultType][]string{
	Maximum: {"anoxxxxxxxxxxxxxxxxx", "axxxxxxxxxxxxxxxxxno"},
	Long: {
		"CvcvnoCvcvCvcv", "CvcvCvcvnoCvcv", "CvcvCvcvCvcvno",
		"CvccnoCvcvCvcv", "CvccCvcvnoCvcv", "CvccCvcvCvcvno",
		"CvcvnoCvccCvcv", "CvcvCvccnoCvcv", "CvcvCvccCvcvno",
		"CvcvnoCvcvCvcc", "CvcvCvcvnoCvcc", "CvcvCvcvCvccno",
		"CvccnoCvccCvcv", "CvccCvccnoCvcv", "CvccCvccCvcvno",
		"CvcvnoCvccCvcc", "CvcvCvccnoCvcc", "CvcvCvccCvccno",
		"CvccnoCvcvCvcc", "CvccCvcvnoCvcc", "CvccCvcvCvccno",
	},
	Medium: {"CvcnoCvc", "CvcCvcno"},
	Short:  {"Cvcn"},
	Basic:  {"aaanaaan", "aannaaan", "aaannaaa"},
	PIN:    {"nnnn"},
	Name:   {"cvccvcvcv"},
	Phrase: {"cvcc cvc cvccvcv cvc", "cvc cvccvcvcv cvcv", "cv cvccv cvc cvcvccv"},
}

// templateChars maps a template character class to the characters it can
// produce. All characters are ASCII, so they can be indexed by byte.
var templateChars = map[rune]string{
	'V': "AEIOU",
	'C': "BCDFGHJKLMNPQRSTVWXYZ",
	'v': "aeiou",
	'c': "bcdfghjklmnpqrstvwxyz",
	'A': "AEIOUBCDFGHJKLMNPQRSTVWXYZ",
	'a': "AEIOUaeiouBCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz",
	'n': "0123456789",
	'o': "@&%?,=[]_:-+*$#!'^~;()/.",
	'x': "AEIOUaeiouBCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz0123456789!@#$%^&*()",
	' ': " ",
}
