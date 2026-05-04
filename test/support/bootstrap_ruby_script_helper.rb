# standard:disable Dotfiles/BanFileSystemClasses
module BootstrapRubyScriptHelper
  def write_ruby_build_stubs(env)
    bin_dir = env.fetch("PATH").split(":").first
    write_ruby_stub(bin_dir)
    write_brew_stub(bin_dir)
    write_mise_ruby_stub(bin_dir)
  end

  def write_ruby_stub(bin_dir)
    write_executable(bin_dir, "ruby", <<~'BASH')
      #!/bin/bash
      printf '%s\n' 'ruby 3.0.0p0'
    BASH
  end

  def write_brew_stub(bin_dir)
    write_executable(bin_dir, "brew", <<~'BASH')
      #!/bin/bash
      printf 'brew %s\n' "$*" >> "$BOOTSTRAP_COMMAND_LOG"
      if [ "$1" = "--prefix" ] && [ "$2" = "libyaml" ]; then
        printf '%s\n' "$LIBYAML_PREFIX"
      fi
    BASH
  end

  def write_mise_ruby_stub(bin_dir)
    write_executable(bin_dir, "mise", <<~'BASH')
      #!/bin/bash
      if [ "$1" = "latest" ] && [ "$2" = "ruby" ]; then
        printf '%s\n' '3.4.0'
      elif [ "$1" = "install" ] && [ "$2" = "ruby@latest" ]; then
        printf 'mise %s RUBY_CONFIGURE_OPTS=%s\n' "$*" "$RUBY_CONFIGURE_OPTS" >> "$BOOTSTRAP_COMMAND_LOG"
      else
        printf 'mise %s\n' "$*" >> "$BOOTSTRAP_COMMAND_LOG"
      fi
    BASH
  end

  def write_executable(bin_dir, name, content)
    path = File.join(bin_dir, name)
    File.write(path, content)
    FileUtils.chmod("+x", path)
  end

  def run_bootstrap_ruby_for_macos(env)
    env = ruby_build_env(env)
    run_bootstrap_commands(env, nil, <<~BASH)
      is_macos() { return 0; }
      bootstrap_ruby
    BASH
  end

  def ruby_build_env(env)
    env.merge(
      "BOOTSTRAP_COMMAND_LOG" => command_log_path(env),
      "LIBYAML_PREFIX" => libyaml_prefix(env)
    )
  end

  def assert_ordered_command(env, first, second)
    log = bootstrap_command_log(env)
    assert log.index(first) < log.index(second), "Expected #{first.inspect} before #{second.inspect}; got #{log.inspect}"
  end

  def mise_install_with_libyaml(env)
    "mise install ruby@latest RUBY_CONFIGURE_OPTS=--with-libyaml-dir=#{libyaml_prefix(env)}"
  end

  def mise_install_with_existing_opts(env)
    "mise install ruby@latest RUBY_CONFIGURE_OPTS=--disable-install-doc --with-libyaml-dir=#{libyaml_prefix(env)}"
  end

  def bootstrap_command_log(env)
    File.readlines(command_log_path(env), chomp: true)
  end

  def command_log_path(env)
    File.join(env.fetch("HOME"), "bootstrap-command-log")
  end

  def libyaml_prefix(env)
    File.join(env.fetch("HOME"), ".homebrew", "opt", "libyaml")
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
