class Dotfiles::Migration::AdoptMiseBootstrap < Dotfiles::Migration
  VERSION = 202607100001

  # Sources with no remaining packages after moving package management to
  # [bootstrap.packages] (gum moved to mise tools, nothing ever used azlux).
  VESTIGIAL_APT_SOURCES = %w[azlux charm].freeze

  OLD_YKNOTIFY_LABEL = "com.user.yknotify".freeze

  def up
    remove_old_yknotify_launchagent
    remove_stale_platform_files
    remove_generated_brewfile
    remove_vestigial_apt_sources
  end

  def down
    raise NotImplementedError, "This migration removes pre-mise-bootstrap artifacts and cannot be safely reversed."
  end

  private

  # mise bootstrap manages yknotify as dev.mise.yknotify now.
  def remove_old_yknotify_launchagent
    return unless @system.macos?

    plist = File.join(@home, "Library", "LaunchAgents", "#{OLD_YKNOTIFY_LABEL}.plist")
    return unless @system.file_exist?(plist)

    execute(shell_script('launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true', OLD_YKNOTIFY_LABEL))
    @system.rm_rf(plist)
  end

  # conf.d/platform.fish (a mise template) replaces the per-platform files.
  def remove_stale_platform_files
    %w[macos.fish linux.fish].each do |name|
      @system.rm_rf(File.join(@home, ".config", "fish", "conf.d", name))
    end
  end

  def remove_generated_brewfile
    @system.rm_rf(File.join(@dotfiles_dir, "Brewfile"))
  end

  def remove_vestigial_apt_sources
    return unless @system.debian?

    VESTIGIAL_APT_SOURCES.each do |name|
      list = "/etc/apt/sources.list.d/#{name}.list"
      keyring = "/usr/share/keyrings/#{name}-archive-keyring.gpg"
      next unless @system.file_exist?(list) || @system.file_exist?(keyring)

      execute(shell_script('sudo rm -f "$1" "$2"', list, keyring))
    end
  end
end
