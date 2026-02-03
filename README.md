# Dotfiles

Set up a fresh Mac with one command.

Most dotfiles repos just copy files to your home folder. This one does more. It installs apps, sets system settings, and gets your whole dev setup ready to go.

## What It Does

- Installs Homebrew and packages from Brewfile
- Sets up SSH keys
- Installs apps and fonts
- Sets Fish as your default shell
- Syncs config files to your home folder
- Sets macOS defaults (Dock, trackpad, screenshots, and more)

## Installation

Clone this repo:

```bash
git clone https://github.com/nateberkopec/dotfiles.git ~/.dotfiles
```

Run the setup:

```bash
cd ~/.dotfiles
./bin/dotf run
```

For verbose output:

```bash
DEBUG=true ./bin/dotf run
```

## Linux (Debian/Ubuntu)

Linux support is in progress and targets Debian-compatible systems (Ubuntu 22.04+).

```bash
./bin/dotf run
```

Packages are defined in `config/config.yml` as a map of package name to `{brew, debian}` entries, with optional `debian_sources` for extra APT repos and `debian_non_apt_packages` for cargo/binary installs.

## Commands

| Command | What it does |
|---------|--------------|
| `dotf run` | Set up your Mac. Safe to run many times. |
| `dotf help` | Show help |

## How It Works

The setup runs in **Steps**. Each Step is a Ruby class that does one thing: install Homebrew, set up Fish, sync config files, etc.

Steps can depend on other steps. The system runs them in the right order.

### Available Steps

See [lib/dotfiles/steps/](lib/dotfiles/steps/) for all steps.

### Adding Your Own Steps

See [docs/implementing-steps.md](docs/implementing-steps.md) to learn how.

## Project Layout

```
bin/           CLI tool
lib/dotfiles/  Core code and steps
files/         Config files to sync to home folder
docs/          Docs for contributors
test/          Test suite
Brewfile       Homebrew packages to install
```

## Contributing

1. Fork this repo
2. Create a branch for your change
3. Run the tests: `rake test`
4. Open a pull request
