require "json"

class Dotfiles::Step::VerifySpotlightExclusionsStep < Dotfiles::Step
  DESCRIPTION = "Verifies that Spotlight Search Privacy excludes the declared folders.".freeze

  macos_only

  def should_run?
    false
  end

  def run
  end

  def complete?
    super
    return true if ENV["CI"]

    (desired_exclusions - excluded_paths).each do |path|
      add_error("Spotlight indexes #{collapse_path_to_home(path)}", fix: "System Settings → Spotlight → Search Privacy: add #{collapse_path_to_home(path)}")
    end
    @errors.empty?
  end

  private

  def desired_exclusions
    Array(@config.fetch("spotlight_exclusions", [])).map { |path| expand_path_with_home(path) }
  end

  def excluded_paths
    output, status = execute(command("plutil", "-extract", "Exclusions", "json", "-o", "-", preferences_path))
    (status == 0) ? JSON.parse(output) : []
  end

  def preferences_path
    File.join(@home, "Library", "Preferences", "com.apple.Spotlight.plist")
  end
end
