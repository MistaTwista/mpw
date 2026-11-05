package main

import (
	"flag"
	"fmt"
	"io"
	"math"
	"strings"

	"github.com/MistaTwista/mpw/go/internal/config"
	"github.com/MistaTwista/mpw/go/internal/mpw"
)

const fullNameEnv = "MPW_FULLNAME"

type flags struct {
	fullName   string
	counter    uint
	counterSet bool // -c/--counter was given explicitly
	resultType mpw.ResultType
	verbose    bool
	quiet      bool
	site       string
}

// parseFlags parses args (without the program name). Long and short forms
// of a flag share one variable, so whichever comes last wins.
func parseFlags(args []string, output io.Writer) (flags, error) {
	var (
		f          flags
		resultType string
	)

	fs := flag.NewFlagSet("mpw", flag.ContinueOnError)
	fs.SetOutput(output)

	fullNameHelp := fmt.Sprintf("full name of the user (overrides $%s and FULL_NAME in %s)", fullNameEnv, config.Path())
	fs.StringVar(&f.fullName, "full-name", "", fullNameHelp)
	fs.StringVar(&f.fullName, "u", "", "shorthand for -full-name")

	counterHelp := "site counter, increase it to rotate the password (overrides the site's counter in the config)"
	fs.UintVar(&f.counter, "counter", 1, counterHelp)
	fs.UintVar(&f.counter, "c", 1, "shorthand for -counter")

	var typeHelp strings.Builder
	typeHelp.WriteString("password template:")
	for _, rt := range mpw.ResultTypes {
		fmt.Fprintf(&typeHelp, "\n%s, %s", rt.Abbr, rt.Type)
	}
	fs.StringVar(&resultType, "site-result-type", string(mpw.Long), typeHelp.String())
	fs.StringVar(&resultType, "t", string(mpw.Long), "shorthand for -site-result-type")

	fs.BoolVar(&f.verbose, "verbose", false, "print the resolved parameters to stderr")
	fs.BoolVar(&f.verbose, "v", false, "shorthand for -verbose")
	fs.BoolVar(&f.quiet, "quiet", false, "print only the password, without identicon and prompt")
	fs.BoolVar(&f.quiet, "q", false, "shorthand for -quiet")

	fs.Usage = func() {
		fmt.Fprintln(fs.Output(), "Usage: mpw [flags] [site]")
		fs.PrintDefaults()
	}

	if err := fs.Parse(args); err != nil {
		return flags{}, err
	}

	fs.Visit(func(fl *flag.Flag) {
		if fl.Name == "counter" || fl.Name == "c" {
			f.counterSet = true
		}
	})
	if f.counterSet && (f.counter < 1 || f.counter > math.MaxUint32) {
		return flags{}, fmt.Errorf("counter must be between 1 and %d, got %d", uint32(math.MaxUint32), f.counter)
	}

	rt, err := mpw.ParseResultType(resultType)
	if err != nil {
		return flags{}, err
	}
	f.resultType = rt

	switch fs.NArg() {
	case 0:
	case 1:
		f.site = fs.Arg(0)
	default:
		return flags{}, fmt.Errorf("expected at most one site name, got %q", fs.Args())
	}

	return f, nil
}

// resolveFullName picks the full name by priority: command line, then
// environment, then config. An empty result means the user has to be asked.
func resolveFullName(f flags, cfg config.Config, getenv func(string) string) string {
	if f.fullName != "" {
		return f.fullName
	}
	if name := getenv(fullNameEnv); name != "" {
		return name
	}
	return cfg.FullName
}

// resolveCounter picks the site counter by priority: command line, then the
// site's entry in the config, then 1.
func resolveCounter(f flags, cfg config.Config, site string) uint32 {
	if f.counterSet {
		return uint32(f.counter)
	}
	if s, ok := cfg.Site(site); ok && s.Counter > 0 {
		return s.Counter
	}
	return 1
}
