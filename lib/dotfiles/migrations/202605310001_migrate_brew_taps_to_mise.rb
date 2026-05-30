class Dotfiles::Migration::MigrateBrewTapsToMise < Dotfiles::Migration
  VERSION = 202605310001

  MISE_TOOLS = [
    "1password-cli@2.34.0",
    "acli@1.3.18-stable",
    "heroku@11.4.0",
    "aqua:planetscale/cli@0.285.0",
    "github:rawnly/splash-cli@4.1.7",
    "github:fabro-sh/fabro@0.246.0-nightly.0"
  ].freeze

  BREW_FORMULAE = %w[
    1password-cli
    acli
    heroku
    pscale
    splash-cli
    fabro-nightly
  ].freeze

  BREW_CASKS = %w[
    1password-cli
    imcp
    trimmy
  ].freeze

  BREW_TAPS = %w[
    1password/tap
    atlassian/acli
    fabro-sh/tap
    heroku/brew
    mattt/tap
    planetscale/tap
    rawnly/tap
    steipete/tap
  ].freeze

  macos_only

  def up
    install_mise_tools
    BREW_FORMULAE.each { |formula| uninstall_formula(formula) }
    BREW_CASKS.each { |cask| uninstall_cask(cask) }
    BREW_TAPS.each { |tap| untap(tap) }
    cleanup_homebrew
  end

  def down
    raise NotImplementedError, "This migration removes obsolete Homebrew installs and cannot be safely reversed."
  end

  private

  def install_mise_tools
    return unless command_exists?("mise")

    execute(command("mise", "--cd", @home, "install", "--yes", *MISE_TOOLS))
  end

  def uninstall_formula(formula)
    return unless brew_formula_installed?(formula)

    execute(brew_command("uninstall", formula))
  end

  def uninstall_cask(cask)
    return unless brew_cask_installed?(cask)

    execute(brew_command("uninstall", "--cask", cask))
  end

  def untap(tap)
    return unless brew_tapped?(tap)

    execute(brew_command("untap", tap))
  end

  def cleanup_homebrew
    return unless command_exists?("brew")

    execute(brew_command("autoremove"))
  end

  def brew_formula_installed?(formula)
    command_succeeds?(brew_command("list", "--formula", formula))
  end

  def brew_cask_installed?(cask)
    command_succeeds?(brew_command("list", "--cask", cask))
  end

  def brew_tapped?(tap)
    command_succeeds?(brew_command("tap-info", tap))
  end

  def brew_command(*args)
    env_command({"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args)
  end
end
