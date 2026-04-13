require "rbconfig"
require "shellwords"

class Dotfiles::Step::SyncAgentLinksStep < Dotfiles::Step
  DEFAULT_CLIENTS = %w[claude factory codex cursor opencode gemini].freeze

  def self.display_name
    "Agent Links"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    configured_clients.any? && agents_root_exists? && mise_available?
  end

  def run
    @system.execute!(sync_command, quiet: false)
  end

  def complete?
    super
    return true if configured_clients.empty?

    add_error("Missing ~/.agents; sync home directory first") unless agents_root_exists?
    add_error("mise not available; cannot run dotagents") unless mise_available?
    @errors.empty?
  end

  private

  def agents_root_exists?
    @system.dir_exist?(File.join(@home, ".agents"))
  end

  def mise_available?
    command_exists?("mise")
  end

  def sync_command
    [
      Shellwords.shellescape(RbConfig.ruby),
      Shellwords.shellescape(driver_path),
      "--home", Shellwords.shellescape(@home),
      "--clients", Shellwords.shellescape(configured_clients.join(",")),
      "--dotagents-command", Shellwords.shellescape(dotagents_command)
    ].join(" ")
  end

  def driver_path
    File.join(@dotfiles_dir, "tools", "drive_dotagents.rb")
  end

  def dotagents_command
    "mise --cd #{Shellwords.shellescape(@dotfiles_dir)} exec npm:@iannuttall/dotagents -- dotagents"
  end

  def configured_clients
    Array(@config.fetch("dotagents_clients", DEFAULT_CLIENTS)).map(&:to_s)
  end
end
