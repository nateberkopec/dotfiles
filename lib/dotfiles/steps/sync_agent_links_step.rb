require "shellwords"

class Dotfiles::Step::SyncAgentLinksStep < Dotfiles::Step
  DEFAULT_CLIENTS = %w[claude factory codex cursor opencode gemini].freeze
  MENU_CLIENTS = %w[claude factory codex cursor opencode gemini github ampcode].freeze

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
    # dotagents is a full-screen TUI. We drive it non-interactively via `script`
    # so it still gets a pseudo-TTY, but we keep stdout/stderr captured here to
    # avoid replaying raw control sequences into dotf's output.
    @system.execute!(sync_command, quiet: true)
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
    "printf '%b' #{Shellwords.shellescape(dotagents_input)} | #{script_command("HOME=#{Shellwords.shellescape(@home)} #{dotagents_command}")}"
  end

  def script_command(command)
    if @system.macos?
      "script -q /dev/null sh -lc #{Shellwords.shellescape(command)}"
    else
      "script -qefc #{Shellwords.shellescape(command)} /dev/null"
    end
  end

  def dotagents_input
    ["\\r", "a", client_selection_input, "\\r\\r\\r", "\\e[B\\e[B\\e[B\\r"].join
  end

  def client_selection_input
    MENU_CLIENTS.map.with_index do |client, index|
      selection = configured_clients.include?(client) ? " " : nil
      down = (index == MENU_CLIENTS.length - 1) ? nil : "\\e[B"
      [selection, down].join
    end.join
  end

  def dotagents_command
    "mise --cd #{Shellwords.shellescape(@dotfiles_dir)} exec npm:@iannuttall/dotagents -- dotagents"
  end

  def configured_clients
    Array(@config.fetch("dotagents_clients", DEFAULT_CLIENTS)).map(&:to_s)
  end
end
