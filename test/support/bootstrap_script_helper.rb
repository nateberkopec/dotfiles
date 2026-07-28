# standard:disable Dotfiles/BanFileSystemClasses
require "fileutils"
require "shellwords"
require "tmpdir"
module BootstrapScriptHelper
  def with_bootstrap_stub
    Dir.mktmpdir("bootstrap-homebrew") do |tmpdir|
      bin_dir = File.join(tmpdir, "bin")
      home_dir = File.join(tmpdir, "home")
      FileUtils.mkdir_p([bin_dir, home_dir])
      write_curl_stub(bin_dir)
      yield(stub_env(bin_dir, home_dir, tmpdir))
    end
  end

  def stub_env(bin_dir, home_dir, tmpdir)
    {
      "HOME" => home_dir,
      "PATH" => "#{bin_dir}:/usr/bin:/bin",
      "CI" => nil,
      "NONINTERACTIVE" => nil,
      "HOMEBREW_INSTALL_ENV_LOG" => File.join(tmpdir, "homebrew-install-env"),
      "HOMEBREW_INSTALLED_BREW" => File.join(home_dir, ".installed-homebrew", "bin", "brew"),
      "HOMEBREW_CONFIGURED_BREW_LOG" => File.join(tmpdir, "configured-brew"),
      "MISE_COMMAND_LOG" => File.join(tmpdir, "mise-commands"),
      "MISE_CONFIG_AT_ACTIVATION_LOG" => File.join(tmpdir, "mise-config-at-activation"),
      "DEBIAN_KEYRING_DIR" => File.join(tmpdir, "keyrings"),
      "DEBIAN_SOURCE_DIR" => File.join(tmpdir, "sources"),
      "APT_CURL_LOG" => File.join(tmpdir, "apt-curl"),
      "APT_SUDO_LOG" => File.join(tmpdir, "apt-sudo")
    }
  end

  def write_curl_stub(bin_dir)
    File.write(File.join(bin_dir, "curl"), <<~'BASH')
      #!/bin/bash
      cat <<'INSTALLER'
      printf '%s\n' "${NONINTERACTIVE-__unset__}" > "$HOMEBREW_INSTALL_ENV_LOG"
      mkdir -p "$(dirname "$HOMEBREW_INSTALLED_BREW")"
      printf '#!/bin/bash\n' > "$HOMEBREW_INSTALLED_BREW"
      chmod +x "$HOMEBREW_INSTALLED_BREW"
      INSTALLER
    BASH
    FileUtils.chmod("+x", File.join(bin_dir, "curl"))
  end

  def write_mise_stub(env)
    bin_dir = env.fetch("PATH").split(":").first
    File.write(File.join(bin_dir, "mise"), <<~'BASH')
      #!/bin/bash
      printf '%s\n' "mise $*" >> "$MISE_COMMAND_LOG"
      if [ "$*" = "activate bash" ]; then
        cat "$HOME/.config/mise/config.toml" > "$MISE_CONFIG_AT_ACTIVATION_LOG"
      fi
    BASH
    FileUtils.chmod("+x", File.join(bin_dir, "mise"))
  end

  def run_ensure_dotfiles_checkout(env)
    run_bootstrap_commands(env, nil, "ensure_dotfiles_checkout")
  end

  def run_install_homebrew(env, terminal:)
    run_bootstrap_commands(env, terminal, "install_homebrew")
  end

  def run_install_homebrew_without_terminal(env)
    run_bootstrap_commands(env, nil, "install_homebrew", no_terminal: true)
  end

  def run_bootstrap_homebrew(env, terminal:)
    run_bootstrap_commands(env, terminal, <<~'BASH')
      is_macos() { return 0; }
      user_has_admin_rights() { return 0; }
      resolve_homebrew_bin() { printf '%s\n' "$HOMEBREW_INSTALLED_BREW"; }
      configure_homebrew_shellenv() { printf '%s\n' "$1" > "$HOMEBREW_CONFIGURED_BREW_LOG"; }
      bootstrap_homebrew
    BASH
  end

  def run_bootstrap_mise(env)
    run_bootstrap_commands(env, nil, "bootstrap_mise")
  end

  def run_prepare_debian_apt_sources(env)
    FileUtils.mkdir_p([env.fetch("DEBIAN_KEYRING_DIR"), env.fetch("DEBIAN_SOURCE_DIR")])
    run_bootstrap_commands(env, nil, <<~'BASH')
      sudo() { printf '%s\n' "$*" >> "$APT_SUDO_LOG"; "$@"; }
      curl() { printf '%s\n' "$2" >> "$APT_CURL_LOG"; printf 'key' > "$4"; }
      gpg() { cp "$4" "$3"; }
      prepare_debian_apt_sources
    BASH
  end

  def run_bootstrap_commands(env, terminal, script, no_terminal: false)
    command = ["source #{Shellwords.escape(bootstrap_path)}", terminal_function(terminal), script].join("\n")
    options = no_terminal ? {in: File::NULL, out: File::NULL} : {}
    assert system(env, "bash", "-c", command, **options)
  end

  def terminal_function(terminal)
    return "" if terminal.nil?
    "has_terminal() { return #{terminal ? 0 : 1}; }"
  end

  def installed_mode(env)
    File.read(env.fetch("HOMEBREW_INSTALL_ENV_LOG")).chomp
  end

  def configured_brew(env)
    File.read(env.fetch("HOMEBREW_CONFIGURED_BREW_LOG")).chomp
  end

  def logged_mise_commands(env)
    File.readlines(env.fetch("MISE_COMMAND_LOG"), chomp: true)
  end

  def bootstrap_path
    File.expand_path("../../bin/bootstrap", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
