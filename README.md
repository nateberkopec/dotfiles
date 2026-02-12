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

## Ubuntu 22.04

Linux support is in progress and currently targets **Ubuntu 22.04 only**.

```bash
./bin/dotf run
```

Packages are defined in `config/config.yml` as a map of package name to `{brew, debian}` entries, with optional `debian_sources` for extra APT repos and `debian_non_apt_packages` for cargo/binary installs.

### Ubuntu GUI test container

```bash
./bin/dotf-ubuntu-gui
```

This one-shot command builds the Ubuntu 22.04 GUI image, starts a fresh ephemeral container, opens noVNC in your browser, and streams container logs in your terminal until you exit.

- noVNC: `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale`
- VNC: `127.0.0.1:5900`
- Runs as `linux/amd64` by default for package compatibility (including 1Password and Google Chrome)
- VNC/noVNC auth is disabled (intended for local testing only)
- `./bin/dotf run` runs automatically at container start; output is streamed to stdout and written to `/tmp/dotf-run.stdout.log` (also tailed in an auto-opened GUI terminal)

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
