class Dotfiles::Migration::RemoveHomebrewCasks < Dotfiles::Migration
  VERSION = 202611200003
  CASKS = %w[1password discord ghostty slack steam tailscale-app telegram visual-studio-code whatsapp zoom].freeze
  LINKED_COMMANDS = %w[code code-tunnel].freeze

  macos_only

  def up
    return unless command_exists?("brew")

    # Forget the casks without uninstalling: the apps stay and keep updating themselves.
    caskroom = homebrew_path("--caskroom")
    CASKS.each { |cask| @system.rm_rf(File.join(caskroom, cask)) } if caskroom
    prefix = homebrew_path("--prefix")
    LINKED_COMMANDS.map { |name| File.join(prefix, "bin", name) }.each { |path| @system.rm_rf(path) if @system.symlink?(path) } if prefix
  end

  def down
    raise NotImplementedError, "This migration stops Homebrew from managing apps and cannot be safely reversed."
  end

  private

  def homebrew_path(flag)
    output, status = @system.execute(homebrew_command(flag))
    path = output.strip
    path if status == 0 && path.start_with?("/")
  end
end
