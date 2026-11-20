require "json"

class Dotfiles::Step::ConfigureThawStep < Dotfiles::Step
  DESCRIPTION = "Syncs the pinned Thaw menu bar profile.".freeze
  LAYOUT_BEHAVIOR = {"keepsLayoutChangesSetting" => false, "reappliesAtLaunchSetting" => true}.freeze
  MACHINE_KEYS = %w[displayConfigurations modifiedAt].freeze
  QUIT_SCRIPT = <<~BASH.freeze
    osascript -e 'tell application id "com.stonerl.Thaw" to quit'
    for _ in $(seq 50); do
      pgrep -x Thaw >/dev/null || exit 0
      sleep 0.2
    done
    exit 1
  BASH

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallThawAppStep]
  end

  def run
    running = command_succeeds?(command("pgrep", "-x", "Thaw"))
    quit_thaw if running
    @system.mkdir_p(profiles_dir)
    @system.write_file(profile_path, source_content)
    @system.write_file(manifest_path, JSON.pretty_generate(merged_manifest))
    execute(command("open", "-b", "com.stonerl.Thaw")) if running
    add_notice(title: "Thaw profile synced", message: "In Thaw Settings → Profiles, apply “#{source_profile["name"]}”. Link it to this display there to have Thaw reapply it at every launch.")
  end

  def complete?
    super
    return true unless @system.file_exist?("/Applications/Thaw.app/Contents/Info.plist")

    add_error("Thaw profile differs from the dotfiles copy") unless covers?(read_json(profile_path), source_profile)
    add_error("Thaw profile is not pinned in profiles.json") unless covers?(manifest_entry, LAYOUT_BEHAVIOR)
    errors.empty?
  end

  private

  def quit_thaw
    _output, status = execute(shell_script(QUIT_SCRIPT))
    raise "Thaw did not quit" unless status == 0
  end

  def covers?(actual, expected)
    return actual == expected unless expected.is_a?(Hash)

    actual.is_a?(Hash) && expected.all? { |key, value| MACHINE_KEYS.include?(key) || covers?(actual[key], value) }
  end

  def merged_manifest
    entry = (manifest_entry || {}).merge(source_profile.slice("id", "name", "createdAt", "modifiedAt"), LAYOUT_BEHAVIOR)
    installed_manifest.reject { |candidate| candidate["id"] == entry["id"] } + [entry]
  end

  def manifest_entry
    installed_manifest.find { |entry| entry["id"] == source_profile["id"] }
  end

  def installed_manifest
    manifest = read_json(manifest_path)
    manifest.is_a?(Array) ? manifest : []
  end

  def read_json(path)
    JSON.parse(@system.read_file(path)) if @system.file_exist?(path)
  rescue JSON::ParserError
    nil
  end

  def source_profile
    @source_profile ||= JSON.parse(source_content)
  end

  def source_content
    @source_content ||= @system.read_file(File.join(@dotfiles_dir, "files", "thaw", "profile.json"))
  end

  def profile_path
    File.join(profiles_dir, "#{source_profile["id"]}.json")
  end

  def manifest_path
    File.join(profiles_dir, "profiles.json")
  end

  def profiles_dir
    File.join(@home, "Library", "Application Support", "Thaw", "Profiles")
  end
end
