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

    font_dir = File.join(@home, "Library", "Fonts")
    font_files = @system.glob("#{font_dir}/*.ttf")
    installed_fonts, status = execute("fc-list", quiet: true)

    unless status == 0
      add_error("Failed to check installed fonts (fc-list command failed)")
      return false
    end

    missing_fonts = font_files.reject do |font_path|
      font_name = File.basename(font_path, ".ttf")
      installed_fonts.include?(font_name)
    end

    if missing_fonts.any?
      missing_fonts.each { |font_path| add_error("Font not installed: #{File.basename(font_path)}") }
      return false
    end

    true
  end
end
