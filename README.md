# Dotfiles

Set up a fresh Mac with one command.

Most dotfiles repos just copy files to your home folder. This one does more. It installs apps, sets system settings, and gets your whole dev setup ready to go.

## What It Does

- Bootstraps a minimal environment with Homebrew, Git, and this repository
- Adds `dotf` to your PATH via `~/.local/bin`
- Runs all defined Steps (see `dotf steps`)

## Commands

| Command | What it does |
|---------|--------------|
| `dotf run` | Set up your Mac. Safe to run many times. |
| `dotf upgrade` | Refresh and upgrade mise tools and Homebrew packages. |
| `dotf steps` | List every setup step with its class name and description. |
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

Run `dotf steps` for the current step list, class names, and descriptions. See [lib/dotfiles/steps/](lib/dotfiles/steps/) for the implementations.

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

