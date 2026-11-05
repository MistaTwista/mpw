# mpw (Go)

A command line client for the [Master Password](https://masterpassword.app) algorithm by
Maarten Billemont, written in Go. Passwords match the official Master Password apps
(algorithm v3); this is checked against the reference test vectors in
[`internal/mpw/testdata/testcases.xml`](internal/mpw/testdata/testcases.xml).

## Install

```sh
go install github.com/MistaTwista/mpw/go/cmd/mpw@latest
```

## Usage

```sh
mpw -t l github.com
```

`mpw` asks for the master password and prints the identicon and the site password:

```
Password:
[ ╚☻╯⛄ ]: Jejr5[RepuSosp
```

The identicon is derived from the full name and master password only. It helps to spot a
mistyped master password and does not affect the generated password.

| Flag | Meaning |
|---|---|
| `-u`, `-full-name` | full name of the user |
| `-c`, `-counter` | site counter, default 1 |
| `-t`, `-site-result-type` | password template: `x` Maximum, `l` Long (default), `m` Medium, `b` Basic, `s` Short, `i` PIN, `n` Name, `p` Phrase |
| `-q`, `-quiet` | print only the password, e.g. `mpw -q github.com \| pbcopy` |
| `-v`, `-verbose` | print the resolved parameters to stderr |

If the site is not given as an argument, `mpw` asks for it. Prompts and errors go to stderr,
so stdout carries only the result.

### Where values come from

Full name, from lowest to highest priority: `FULL_NAME` in the config, the `MPW_FULLNAME`
environment variable, the `-u` flag. If none is set, `mpw` asks for it.

Counter, from lowest to highest priority: 1, the site's `counter` in the config, the `-c` flag.

### Config

`~/.config/mpw/config.json`, or `$XDG_CONFIG_HOME/config.json` when `XDG_CONFIG_HOME` is set.
`FULL_NAME` is shared with the Python client in this repository.

```json
{
  "FULL_NAME": "Robert Lee Mitchell",
  "sites": [
    {"name": "github.com", "counter": 2}
  ]
}
```

## Layout

| Path | Contents |
|---|---|
| `cmd/mpw` | the command: flags, value priorities, prompts |
| `internal/mpw` | the algorithm: master key, site key, templates, identicon |
| `internal/config` | the JSON config |

## Credits

- Algorithm: Maarten Billemont, [masterpassword.app](https://masterpassword.app).
- First Go version of this client: Emil Johansson, [emiljoha/mpw](https://github.com/emiljoha/mpw).
- Split into packages, config priorities and tests: Maxim Kern.
