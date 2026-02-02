require "shellwords"

class Dotfiles::Step::InstallFontsStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

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
    installed, status = execute("fc-list", quiet: true)
    unless status == 0
      add_error("Failed to check installed fonts (fc-list command failed)")
      return false
    end
    report_missing_fonts(installed)
    @errors.empty?
  end

  private

  def report_missing_fonts(installed)
    missing_fonts(installed).each { |font_path| add_error("Font not installed: #{File.basename(font_path)}") }
  end

  def missing_fonts(installed)
    font_files.reject { |path| installed.include?(File.basename(path, ".ttf")) }
  end

  def font_files
    @system.glob("#{File.join(@home, "Library", "Fonts")}/*.ttf")
  end
end
