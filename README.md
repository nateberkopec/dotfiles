# Dotfiles

Set up a fresh Mac with one command.

Most dotfiles repos just copy files to your home folder. This one does more. It installs apps, sets system settings, and gets your whole dev setup ready to go.

## What It Does

- Bootstraps Homebrew, then installs packages from Brewfile
- Sets up SSH keys
- Installs apps and fonts
- Sets Fish as your default shell
- Syncs config files to your home folder
- Adds `dotf` to your PATH via `~/.local/bin`
- Sets macOS defaults (Dock, trackpad, screenshots, and more)

## Commands

| Command | What it does |
|---------|--------------|
| `dotf run` | Set up your Mac. Safe to run many times. |
| `dotf upgrade` | Refresh and upgrade mise tools and Homebrew packages. |
| `dotf help` | Show help |

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

For verbose output that also streams subprocess output:

```bash
DEBUG=true ./bin/dotf run
```

## How It Works

The setup runs in **Steps**. Each Step is a Ruby class that does one thing: install packages, set up Fish, sync config files, etc.

Steps can depend on other steps.

### Available Steps

See [lib/dotfiles/steps/](lib/dotfiles/steps/) for all steps.

### Adding Your Own Steps

See [docs/implementing-steps.md](docs/implementing-steps.md) to learn how.

### Ubuntu 22.04

See [docs/ubuntu-22.04.md](docs/ubuntu-22.04.md) for Ubuntu setup and GUI test container notes.

## Project Layout

```
bin/           CLI tool
lib/dotfiles/  Core code and steps
files/         Config files to sync to home folder
docs/          Docs for contributors
test/          Test suite
```

