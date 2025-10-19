class Dotfiles::Step::InstallFontsStep < Dotfiles::Step
  def should_run?
    if ci_or_noninteractive?
      debug "Skipping font installation (requires GUI) in CI/non-interactive environment"
      return false
    end

    font_dir = "#{@dotfiles_dir}/fonts"
    font_files = @system.glob("#{font_dir}/*.ttf")
    installed_fonts, = execute("fc-list")

    font_files.any? do |font_path|
      font_name = File.basename(font_path)
      !installed_fonts.include?(font_name)
    end
  end

  def run
    font_dir = "#{@dotfiles_dir}/fonts"

    @system.glob("#{font_dir}/*.ttf").each do |font_path|
      font_name = File.basename(font_path)
      debug "Installing font: #{font_name}"
      execute("open #{Shellwords.escape(font_path)}")
    end
  end

  def complete?
    font_dir = "#{@dotfiles_dir}/fonts"
    font_files = @system.glob("#{font_dir}/*.ttf")
    installed_fonts, status = execute("fc-list", quiet: true)
    return false unless status == 0

    all_fonts_installed = font_files.all? do |font_path|
      font_name = File.basename(font_path, ".ttf")
      installed_fonts.include?(font_name)
    end

    if all_fonts_installed
      true
    elsif ci_or_noninteractive?
      nil
    else
      false
    end
  end

  # Sync selected fonts from the system back into the repo.
  # This only refreshes fonts that already exist under files/fonts
  # to avoid slurping the user's entire font library.
  def update
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    @system.mkdir_p(dest_dir)

    system_font_dirs = [
      File.expand_path("~/Library/Fonts"),
      "/Library/Fonts"
    ].select { |d| @system.dir_exist?(d) }

    # Only refresh fonts that are already tracked in the repo
    tracked_fonts = @system.glob(File.join(dest_dir, "*.{ttf,otf}"))
    return if tracked_fonts.empty?

    tracked_fonts.each do |tracked|
      basename = File.basename(tracked)
      src = system_font_dirs.map { |d| File.join(d, basename) }.find { |p| @system.file_exist?(p) }
      next unless src

      begin
        @system.cp(src, File.join(dest_dir, basename))
      rescue => e
        debug "Failed to copy font #{basename}: #{e.message}"
      end
    end
  end
end
