// Command mpw prints the Master Password site password for a site.
//
// Prompts and diagnostics go to stderr, so stdout carries only the result.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"

	"golang.org/x/term"

	"github.com/MistaTwista/mpw/internal/config"
	"github.com/MistaTwista/mpw/internal/mpw"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return
		}
		fmt.Fprintln(os.Stderr, "mpw:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	f, err := parseFlags(args, os.Stderr)
	if err != nil {
		return err
	}

	cfg, err := config.Load(config.Path())
	if err != nil {
		return fmt.Errorf("read config: %w", err)
	}

	stdin := bufio.NewReader(os.Stdin)

	fullName := resolveFullName(f, cfg, os.Getenv)
	if fullName == "" {
		if fullName, err = prompt(stdin, "Full Name: "); err != nil {
			return err
		}
	}

	site := f.site
	if site == "" {
		if site, err = prompt(stdin, "Site Name: "); err != nil {
			return err
		}
	}

	counter := resolveCounter(f, cfg, site)
	resultType, err := resolveResultType(f, cfg, site)
	if err != nil {
		return err
	}
	if f.verbose {
		fmt.Fprintf(os.Stderr, "full name: %s\nsite: %s\ncounter: %d\ntype: %s\n", fullName, site, counter, resultType)
	}

	if !f.quiet {
		fmt.Fprint(os.Stderr, "Password: ")
	}
	masterPassword, err := term.ReadPassword(int(os.Stdin.Fd()))
	if !f.quiet {
		fmt.Fprintln(os.Stderr)
	}
	if err != nil {
		return fmt.Errorf("read master password: %w", err)
	}

	password, err := mpw.Password(fullName, string(masterPassword), site, counter, resultType)
	if err != nil {
		return fmt.Errorf("generate password: %w", err)
	}

	if f.quiet {
		fmt.Print(password)
		return nil
	}
	fmt.Printf("[ %s ]: %s\n", mpw.NewIdenticon(fullName, string(masterPassword)).ANSI(), password)
	return nil
}

func prompt(r *bufio.Reader, label string) (string, error) {
	fmt.Fprint(os.Stderr, label)
	line, err := r.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("read %s: %w", strings.TrimSuffix(label, ": "), err)
	}
	line = strings.TrimSpace(line)
	if line == "" {
		return "", fmt.Errorf("%s must not be empty", strings.TrimSuffix(label, ": "))
	}
	return line, nil
}
