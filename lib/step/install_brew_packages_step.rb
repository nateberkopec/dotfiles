class InstallBrewPackagesStep < Step
  attr_reader :skipped_packages, :skipped_casks

  def self.depends_on
    [InstallHomebrewStep]
  end

  def initialize(**kwargs)
    super
    @skipped_packages = []
    @skipped_casks = []
    @brewfile_path = File.join(@dotfiles_dir, "Brewfile")
    @ran = false
  end

  def run
    debug "Installing command-line tools via Homebrew..."

    generate_brewfile

    result = system("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
    if result
      debug "All packages already installed"
      @ran = true
      return
    end

    output = `brew bundle install --file=#{@brewfile_path} 2>&1`
    exit_status = $?.exitstatus

    if exit_status != 0
      output.each_line do |line|
        if line =~ /Error: .* ([\w\-]+)/ || line =~ /failed to install ([\w\-]+)/i
          package = $1
          packages = @config.packages["brew"]["packages"]
          casks = @config.packages["brew"]["casks"]

          if packages.include?(package)
            @skipped_packages << package
          elsif casks.include?(package)
            @skipped_casks << package
          end
        end
      end
      debug "Some packages failed to install"
      debug "Output: #{output}" if @debug
    end

    @ran = true
  end

  def complete?
    return true if @ran && (@skipped_packages.any? || @skipped_casks.any?)
    return false unless File.exist?(@brewfile_path)
    system("brew bundle check --file=#{@brewfile_path} --no-upgrade >/dev/null 2>&1")
  rescue
    false
  end

  def update
    return unless command_exists?("brew")

    dest_dir = File.join(@dotfiles_dir, "files", "brew")
    FileUtils.mkdir_p(dest_dir)

    brewfile_dest = File.join(@dotfiles_dir, "Brewfile")
    system("brew bundle dump --file=#{brewfile_dest} --force --no-vscode >/dev/null 2>&1")

    begin
      formulae = execute("brew list --formula", capture_output: true, quiet: true)
      File.write(File.join(dest_dir, "formulae.txt"), formulae.strip + "\n")
    rescue => e
      debug "Failed to export brew formulae: #{e.message}"
    end

    begin
      casks = execute("brew list --cask", capture_output: true, quiet: true)
      File.write(File.join(dest_dir, "casks.txt"), casks.strip + "\n")
    rescue => e
      debug "Failed to export brew casks: #{e.message}"
    end
  end

  private

  def generate_brewfile
    packages = @config.packages["brew"]["packages"]
    cask_packages = @config.packages["brew"]["casks"]

    brewfile_content = []
    packages.each { |pkg| brewfile_content << "brew \"#{pkg}\"" }
    cask_packages.each { |cask| brewfile_content << "cask \"#{cask}\"" }

    File.write(@brewfile_path, brewfile_content.join("\n") + "\n")
  end
end
