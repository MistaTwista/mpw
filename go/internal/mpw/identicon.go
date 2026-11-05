package mpw

import (
	"crypto/hmac"
	"crypto/sha256"
	"fmt"
)

// Identicon is a short picture derived from the full name and master
// password. It lets the user recognise a mistyped master password before
// using the generated site password. It does not take part in password
// derivation.
type Identicon struct {
	Text  string
	Color int // ANSI foreground color: 1 red .. 7 white
}

var (
	leftArms    = []string{"╔", "╚", "╰", "═"}
	bodies      = []string{"█", "░", "▒", "▓", "☺", "☻"}
	rightArms   = []string{"╗", "╝", "╯", "═"}
	accessories = []string{
		"◈", "◎", "◐", "◑", "◒", "◓", "☀", "☁", "☂", "☃", "☄", "★",
		"☆", "☎", "☏", "⎈", "⌂", "☘", "☢", "☣", "☕", "⌚", "⌛", "⏰",
		"⚡", "⛄", "⛅", "☔", "♔", "♕", "♖", "♗", "♘", "♙", "♚", "♛",
		"♜", "♝", "♞", "♟", "♨", "♩", "♪", "♫", "⚐", "⚑", "⚔", "⚖",
		"⚙", "⚠", "⌘", "⏎", "✄", "✆", "✈", "✉", "✌",
	}
)

// NewIdenticon derives the identicon:
//
//	seed = HMAC-SHA-256( key = <master password>, message = <name> )
//	icon = leftArm[seed[0]] . body[seed[1]] . rightArm[seed[2]] . accessory[seed[3]]
//	color = seed[4] % 7 + 1
//
// where each index is taken modulo the length of its list.
func NewIdenticon(fullName, masterPassword string) Identicon {
	mac := hmac.New(sha256.New, []byte(masterPassword))
	mac.Write([]byte(fullName))
	seed := mac.Sum(nil)

	pick := func(list []string, b byte) string { return list[int(b)%len(list)] }
	return Identicon{
		Text:  pick(leftArms, seed[0]) + pick(bodies, seed[1]) + pick(rightArms, seed[2]) + pick(accessories, seed[3]),
		Color: int(seed[4])%7 + 1,
	}
}

func (i Identicon) String() string { return i.Text }

// ANSI returns the identicon wrapped in its terminal color.
func (i Identicon) ANSI() string {
	return fmt.Sprintf("\033[3%dm%s\033[0m", i.Color, i.Text)
}
