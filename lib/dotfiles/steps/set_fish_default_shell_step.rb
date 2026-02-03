class Dotfiles::Step::SetFishDefaultShellStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  def self.depends_on
    Dotfiles::Step.system_packages_steps
  end

  def run
    debug "Setting Fish as the default shell..."
    return add_error("Fish not found on PATH") if fish_path.empty?
    add_fish_to_shells unless fish_in_shells?
    change_default_shell
  end

  def complete?
    super
    add_error("Fish not found on PATH") if fish_path.empty?
    add_error("Fish is not set as the default shell (current: #{current_shell.strip})") unless fish_is_default?
    @errors.empty?
  end

  private

  def add_fish_to_shells
    debug "Adding Fish to allowed shells..."
    _, status = execute("bash -lc 'echo #{fish_path} >> /etc/shells'", sudo: true)
    add_error("Failed to add Fish to /etc/shells") unless status == 0
  end

  def change_default_shell
    debug "Changing default shell to Fish..."
    user = unix_username
    if user.empty?
      execute("chsh -s #{fish_path}")
    else
      execute("chsh -s #{fish_path} #{user}")
    end
  end

  def fish_path
    return @fish_path if defined?(@fish_path)
    output, status = @system.execute("command -v fish 2>/dev/null")
    return @fish_path = output.strip if status == 0 && !output.strip.empty?

    candidates = [
      "/opt/homebrew/bin/fish",
      "/usr/local/bin/fish",
      "/usr/bin/fish",
      "/home/linuxbrew/.linuxbrew/bin/fish"
    ]
    @fish_path = candidates.find { |path| @system.file_exist?(path) }.to_s
  end

  def fish_in_shells?
    return false if fish_path.empty?
    @system.readlines("/etc/shells").any? { |line| line.strip == fish_path }
  end

  def current_shell
    if @system.macos?
      execute("dscl . -read ~/ UserShell", quiet: true).first
    else
      shell = shell_from_getent(unix_uid)
      return shell unless shell.empty?
      shell = shell_from_getent(unix_username)
      return shell unless shell.empty?
      ENV.fetch("SHELL", "")
    end
  end

  def shell_from_getent(key)
    return "" if key.to_s.strip.empty?
    output, status = execute("getent passwd #{key}", quiet: true)
    return "" unless status == 0 && !output.to_s.strip.empty?
    output.to_s.split(":").last.to_s
  end

  def unix_username
    command_output("id -un")
  end

  def unix_uid
    command_output("id -u")
  end

  def command_output(command)
    output, status = execute(command, quiet: true)
    return "" unless status == 0
    output.strip
  end

  def fish_is_default?
    return false if fish_path.empty?
    current_shell.include?(fish_path)
  end
end
