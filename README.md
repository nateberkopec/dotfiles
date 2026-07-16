# Dotfiles

Set up a fresh host with one command for development in the way I like it.

This is intended exclusively for my personal use, though I encourage you to steal the patterns, tools and concepts within.

## What It Does

Most dotfiles repos just copy files to your home folder. This one does more. It installs apps, sets system settings, and more.

When you run `dotf run` it will:

- Bootstrap a minimal environment with Homebrew, Git, and this repository
- Add `dotf` to your PATH via `~/.local/bin`
- Run all defined Steps (see `dotf steps`)

## Commands

| Command | What it does |
|---------|--------------|
| `dotf run` | Converge this host, including installing missing managed packages and applying safe local upgrades/pruning. Safe to run many times. |
| `dotf outdated` | Show available upgrades for pinned mise tools, pinned Pi packages/extensions, and managed Homebrew packages, then write a Pi upgrade prompt under `tmp/`. |
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

## Philosophies

This is not intended to be run by anyone except me.

Supported platforms:

1. MacOS with sudo
2. MacOS without sudo
3. Ubuntu 22.04

In general, because `mise` is crossplatform, if we can do it with `mise`, we should do it with `mise`.

Managed tools are pinned to explicit versions. `dotf run` converges the machine to those pins and handles safe local cleanup; `dotf outdated` reports newer pins to review and prints the `pi "$(cat tmp/pi-upgrade-prompt-...)"` command to start an update PR.

`dotf run` aggressively overwrites existing user state. This repo is the source of truth.

Config should drive data, Steps should drive behavior.

Generated artifacts should not be edited as sources of truth, e.g. we ignore generated `Brewfile`.

We do not store secrets on the system in plaintext.

As far as OS settings go, I prefer low/no animation and performance.

There is a GTD-style `~/Documents/Inbox`, which several Steps interact with.

I'm constantly using LLM agents in YOLO mode on my system, so basically I've installed the equivalent of a North Korean rootkit that's running all the time and my system needs to not leave lying around any sharp objects or passwords. See .gem/credentials as an example of the mitigations I take as a result.

We don't trust agents, we make sure they do the right thing and lock destructive/bad actions behind human authentication (immutable flags, 1password).

## How It Works

The setup runs in **Steps**. Each Step is a Ruby class that does one thing: install packages, set up Fish, sync config files, etc.

Steps can depend on other steps.

### Available Steps

Run `dotf steps` for the current step list, class names, and descriptions. See [lib/dotfiles/steps/](lib/dotfiles/steps/) for the implementations.

### Adding Your Own Steps

See [docs/implementing-steps.md](docs/implementing-steps.md) to learn how.

### Ubuntu 22.04

I'm working on supporting Ubuntu in addition to MacOS. It's in a ~half finished state but should eventually become a full "target" OS.

See [docs/ubuntu-22.04.md](docs/ubuntu-22.04.md) for Ubuntu setup and GUI test container notes.

## Project Layout

```
bin/           CLI tool
lib/dotfiles/  Core code and steps
files/         Config files to sync to home folder
docs/          Docs for contributors
test/          Test suite
```

