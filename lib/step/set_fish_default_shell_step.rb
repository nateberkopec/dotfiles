class SetFishDefaultShellStep < Step
  def self.depends_on
    [InstallBrewPackagesStep]
  end
  def should_run?
    if ci_or_noninteractive?
      debug 'Skipping default shell change (chsh) in CI/non-interactive environment'
      return false
    end

    fish_path = `which fish`.strip
    current_shell = execute('dscl . -read ~/ UserShell', capture_output: true)
    !current_shell.include?(fish_path)
  end

  def run
    debug 'Setting Fish as the default shell...'
    fish_path = `which fish`.strip

    unless File.readlines('/etc/shells').any? { |line| line.strip == fish_path }
      debug 'Adding Fish to allowed shells...'
      execute("echo #{fish_path} | sudo tee -a /etc/shells", sudo: true)
    end

    debug 'Changing default shell to Fish...'
    execute("chsh -s #{fish_path}")
  end

  def complete?
    fish_path = `which fish`.strip
    current_shell = execute('dscl . -read ~/ UserShell', capture_output: true, quiet: true)
    current_shell.include?(fish_path)
  rescue
    false
  end
end