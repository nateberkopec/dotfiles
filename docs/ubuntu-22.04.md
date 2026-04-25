# Ubuntu 22.04

Linux support is in progress and currently targets **Ubuntu 22.04 only**.

## Run the setup

```bash
./bin/dotf run
```

Packages are defined in `config/config.yml` as a map of package name to `{brew, debian}` entries, with optional `debian_sources` for extra APT repos and `debian_non_apt_packages` for cargo/binary installs.

## Ubuntu GUI test container

```bash
./bin/dotf-ubuntu-gui
```

This one-shot command builds the Ubuntu 22.04 GUI image, starts a fresh ephemeral container, opens noVNC in your browser, and streams container logs in your terminal until you exit.

- noVNC: `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale`
- VNC: `127.0.0.1:5900`
- Runs as `linux/amd64` by default for package compatibility (including 1Password and Google Chrome)
- VNC/noVNC auth is disabled (intended for local testing only)
- `./bin/dotf run` runs automatically at container start; output is streamed to stdout and written to `/tmp/dotf-run.stdout.log` (also tailed in an auto-opened GUI terminal)
