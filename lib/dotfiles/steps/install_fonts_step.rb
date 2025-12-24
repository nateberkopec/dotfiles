require "shellwords"

class Dotfiles::Step::InstallFontsStep < Dotfiles::Step
  def self.depends_on
    [Dotfiles::Step::SyncHomeDirectoryStep]
  end

  def should_run?
    # Fonts are synced by SyncHomeDirectoryStep, no action needed
    false
  end

  def run
    # No-op: fonts are synced by SyncHomeDirectoryStep
  end

  def complete?
    super
    return true if ci_or_noninteractive?
    unless fc_list_available?
      add_error("Failed to check installed fonts (fc-list command failed)")
      return false
    end
    report_missing_fonts
    @errors.empty?
  end

  private

  def fc_list_available?
    _, status = execute("fc-list", quiet: true)
    status == 0
  end

  def report_missing_fonts
    missing_fonts.each { |font_path| add_error("Font not installed: #{File.basename(font_path)}") }
  end

  def missing_fonts
    installed, = execute("fc-list", quiet: true)
    font_files.reject { |path| installed.include?(File.basename(path, ".ttf")) }
  end

  def font_files
    @system.glob("#{File.join(@home, "Library", "Fonts")}/*.ttf")
  end
end
