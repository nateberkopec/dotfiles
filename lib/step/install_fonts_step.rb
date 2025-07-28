class InstallFontsStep < Step
  def should_run?
    if ci_or_noninteractive?
      debug 'Skipping font installation (requires GUI) in CI/non-interactive environment'
      return false
    end

    font_dir = "#{@dotfiles_dir}/fonts"
    font_files = Dir.glob("#{font_dir}/*.ttf")
    installed_fonts = execute('fc-list', capture_output: true)

    font_files.any? do |font_path|
      font_name = File.basename(font_path)
      !installed_fonts.include?(font_name)
    end
  end

  def run
    font_dir = "#{@dotfiles_dir}/fonts"

    Dir.glob("#{font_dir}/*.ttf").each do |font_path|
      font_name = File.basename(font_path)
      debug "Installing font: #{font_name}"
      execute("open #{Shellwords.escape(font_path)}")
    end
  end

  def complete?
    font_dir = "#{@dotfiles_dir}/fonts"
    font_files = Dir.glob("#{font_dir}/*.ttf")
    installed_fonts = execute('fc-list', capture_output: true, quiet: true)

    all_fonts_installed = font_files.all? do |font_path|
      font_name = File.basename(font_path, '.ttf')
      installed_fonts.include?(font_name)
    end

    if all_fonts_installed
      true
    elsif ci_or_noninteractive?
      nil
    else
      false
    end
  rescue
    false
  end
end
