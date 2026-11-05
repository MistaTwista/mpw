// Package mpw implements the Master Password algorithm by Maarten Billemont
// (https://masterpassword.app): site passwords are derived from the user's
// full name, master password, site name and counter, so nothing has to be
// stored.
package mpw

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"strings"

	"golang.org/x/crypto/scrypt"
)

const scope = "com.lyndir.masterpassword"

// Password derives the site password in one call: master key, site key,
// then the template of the given type.
func Password(fullName, masterPassword, siteName string, counter uint32, t ResultType) (string, error) {
	master, err := MasterKey(fullName, masterPassword)
	if err != nil {
		return "", err
	}
	return SitePassword(SiteKey(master, siteName, counter), t)
}

// Phase 1: Your identity
//
// Your identity is defined by your master key. This key unlocks all of your
// doors. Your master key is the cryptographic result of two components:
//
//  1. Your <name> (identification)
//  2. Your <master password> (authentication)
//
// Your master password is your personal secret and your name scopes that
// secret to your identity. Together, they create a cryptographic identifier
// that is unique to your person.
//
//	masterKey = SCRYPT( key, seed, N, r, p, dkLen )
//	key = <master password>
//	seed = scope . LEN(<name>) . <name>
//	N = 32768
//	r = 8
//	p = 2
//	dkLen = 64
//
// We employ the SCRYPT cryptographic function to derive a 64-byte
// cryptographic key from the user's name and master password using a fixed
// set of parameters.
func MasterKey(fullName, masterPassword string) ([]byte, error) {
	seed := scoped(fullName)
	return scrypt.Key([]byte(masterPassword), seed, 32768, 8, 2, 64)
}

// Phase 2: Your site key
//
// Your site key is a derivative from your master key when it is used to
// unlock the door to a specific site. Your site key is the result of three
// components:
//
//  1. Your <site name> (identification)
//  2. Your <master key> (authentication)
//  3. Your <site counter>
//
// Your master key ensures only your identity has access to this key and your
// site name scopes the key to your site. The site counter ensures you can
// easily create new keys for the site should a key become compromised.
// Together, they create a cryptographic identifier that is unique to your
// account at this site.
//
//	siteKey = HMAC-SHA-256( key, seed )
//	key = <master key>
//	seed = scope . LEN(<site name>) . <site name> . <counter>
//
// We employ the HMAC-SHA-256 cryptographic function to derive a 32-byte
// cryptographic site key from the site name and master key scoped to a given
// counter value.
func SiteKey(masterKey []byte, siteName string, counter uint32) []byte {
	seed := binary.BigEndian.AppendUint32(scoped(siteName), counter)
	mac := hmac.New(sha256.New, masterKey)
	mac.Write(seed) // hash.Hash.Write never returns an error
	return mac.Sum(nil)
}

// Phase 3: Your site password
//
// Your site password is an identifier derived from your site key in
// compliance with the site's password policy.
//
// The purpose of this step is to render the site's cryptographic key into a
// format that the site's password input will accept.
//
// Master Password declares several site password formats and uses these
// pre-defined password "templates" to render the site key legible.
//
//	template = templates[ <site key>[0] % LEN( templates ) ]
//
//	for i in 0..LEN( template )
//	    passChars = templateChars[ template[i] ]
//	    passWord[i] = passChars[ <site key>[i+1] % LEN( passChars ) ]
//
// We resolve a template to use for the password from the site key's first
// byte. As we iterate the template, we use it to translate site key bytes
// into password characters. The result is a site password in the form
// defined by the site template scoped to our site key.
func SitePassword(siteKey []byte, t ResultType) (string, error) {
	templates, ok := templates[t]
	if !ok {
		return "", fmt.Errorf("unknown result type %q", t)
	}
	if len(siteKey) == 0 {
		return "", fmt.Errorf("empty site key")
	}

	tpl := templates[int(siteKey[0])%len(templates)]
	if len(tpl) >= len(siteKey) {
		return "", fmt.Errorf("template %q needs %d key bytes, site key has %d", tpl, len(tpl)+1, len(siteKey))
	}

	var b strings.Builder
	for i, class := range tpl {
		chars := templateChars[class]
		b.WriteByte(chars[int(siteKey[i+1])%len(chars)])
	}
	return b.String(), nil
}

// scoped builds "scope . LEN(s) . s", the common prefix of both key seeds.
// Numbers are encoded as 32-bit unsigned big-endian integers.
func scoped(s string) []byte {
	seed := []byte(scope)
	seed = binary.BigEndian.AppendUint32(seed, uint32(len(s)))
	return append(seed, s...)
}
