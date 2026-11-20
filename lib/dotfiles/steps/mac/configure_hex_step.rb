require "json"

class Dotfiles::Step::ConfigureHexStep < Dotfiles::Step
  DESCRIPTION = "Locks Hex updates to mise and enables its cleanup transform, Labs, and vocabulary.".freeze
  PROFILE_ID = "com.nateberkopec.dotfiles.hex".freeze
  HEX = "/Applications/Hex.app/Contents/MacOS/hex".freeze

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallMiseAppsStep]
  end

  def run
    request_profile unless profile_installed?
    return add_notice(title: "Hex setup", message: "Open Hex, finish onboarding, then run dotf again to apply its settings.") unless hex_running?

    apply_transformations
    desired.fetch("labs").each { |lab| hex("settings", "set", "labs.#{lab}", "on") }
    missing_vocabulary.each { |term, spellings| hex("vocabulary", "add", term, "--sounds-like", spellings.join(",")) }
  end

  def complete?
    super
    add_error("Hex update lock profile is not installed", fix: "System Settings → General → Device Management → Hex (dotfiles) → Install") unless profile_installed?
    add_error("Hex settings do not match files/hex/settings.json") unless settings_current?
    errors.empty?
  end

  private

  def request_profile
    execute(command("open", profile_path))
    add_notice(title: "Hex update lock", message: "Approve the “Hex (dotfiles)” profile in System Settings → General → Device Management so only mise updates Hex.")
  end

  def apply_transformations
    mode = settings.dig("dictation_processing", "default_mode") || {}
    wanted = (mode.fetch("transformations", []) | desired.fetch("transformations"))
    hex("settings", "set", "dictation_processing.default_mode", JSON.generate(mode.merge("transformations" => wanted)))
  end

  def settings_current?
    return false if settings.empty?

    transformations = settings.dig("dictation_processing", "default_mode", "transformations") || []
    (desired.fetch("transformations") - transformations).empty? &&
      desired.fetch("labs").all? { |lab| settings.dig("labs", lab) == true } &&
      missing_vocabulary.empty?
  end

  def missing_vocabulary
    current = (settings["vocabulary"] || []).to_h { |entry| [entry["term"], entry["sounds_like"] || []] }
    desired.fetch("vocabulary").select { |term, spellings| !current.key?(term) || (spellings - current[term]).any? }
  end

  def profile_installed?
    output, status = execute(command("/usr/bin/profiles", "list", "-type", "configuration"))
    status == 0 && output.include?(PROFILE_ID)
  end

  def hex_running?
    command_succeeds?(command(HEX, "status"))
  end

  def hex(*args)
    output, status = execute(command(HEX, *args))
    add_error(format_command_error(command(HEX, *args), status, output)) unless status == 0
  end

  def settings
    path = File.join(@home, "Library", "Application Support", "hex", "settings.json")
    @system.file_exist?(path) ? JSON.parse(@system.read_file(path)) : {}
  end

  def desired
    @desired ||= JSON.parse(@system.read_file(File.join(@dotfiles_dir, "files", "hex", "settings.json")))
  end

  def profile_path
    File.join(@dotfiles_dir, "files", "hex", "hex.mobileconfig")
  end
end
