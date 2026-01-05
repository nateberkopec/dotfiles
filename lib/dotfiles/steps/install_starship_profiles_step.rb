class Dotfiles::Step::InstallStarshipProfilesStep < Dotfiles::Step
  UPSTREAM_PR = "https://github.com/starship/starship/pull/6894".freeze
  PROFILES_DIR = "Library/Application Support/starship/profiles".freeze

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    !starship_profiles_installed? || !profiles_config_exists?
  end

  def run
    check_upstream_pr_still_open!
    install_starship_profiles unless starship_profiles_installed?
    setup_profiles_config unless profiles_config_exists?
  end

  def complete?
    super
    add_error("starship-profiles not installed") unless starship_profiles_installed?
    add_error("profiles.toml not configured") unless profiles_config_exists?
    @errors.empty?
  end

  private

  def check_upstream_pr_still_open!
    output, status = execute("gh pr view #{UPSTREAM_PR} --json state -q .state", quiet: true)
    return if status != 0

    state = output.strip.downcase
    return if state == "open"

    raise "PR #{UPSTREAM_PR} is now #{state}. " \
          "Starship may have native multi-config support. " \
          "Update this step or remove starship-profiles dependency."
  end

  def install_starship_profiles
    execute("cargo install starship-profiles")
  end

  def setup_profiles_config
    @system.mkdir_p(profiles_dir)
    @system.write_file(profiles_toml_path, default_profiles_toml)
    @system.write_file(default_profile_path, default_starship_config)
  end

  def starship_profiles_installed?
    @system.file_exist?(cargo_starship_path)
  end

  def cargo_starship_path
    File.join(@home, ".cargo/bin/starship")
  end

  def profiles_config_exists?
    @system.file_exist?(profiles_toml_path)
  end

  def profiles_dir
    File.join(@home, PROFILES_DIR)
  end

  def profiles_toml_path
    File.join(@home, "Library/Application Support/starship/profiles.toml")
  end

  def default_profile_path
    File.join(profiles_dir, "default.toml")
  end

  def default_profiles_toml
    <<~TOML
      # starship-profiles configuration
      # Patterns are matched against the current directory
      # First matching profile wins
      # See: https://docs.rs/crate/starship-profiles/latest

      # Example: disable git for large repos
      # [[profile]]
      # name = "no-git"
      # patterns = ["~/large-repo"]
    TOML
  end

  def default_starship_config
    <<~TOML
      # Default starship profile
      # Copy your ~/.config/starship.toml settings here
      # This profile is used when no other patterns match
    TOML
  end
end
