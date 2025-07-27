#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'

class Step
  @@steps = []

  def self.inherited(subclass)
    @@steps << subclass
  end

  def self.all_steps
    @@steps
  end

  def initialize(debug:, dotfiles_repo:, dotfiles_dir:, home:)
    @debug = debug
    @dotfiles_repo = dotfiles_repo
    @dotfiles_dir = dotfiles_dir
    @home = home
  end

  def should_run?
    true
  end

  def run
    raise NotImplementedError, 'Subclasses must implement #run'
  end

  private

  def debug(message)
    puts message if @debug
  end

  def execute(command, quiet: !@debug, sudo: false)
    if sudo && ci_or_noninteractive?
      debug "Skipping sudo command in CI/non-interactive environment: #{command}"
      return ""
    end

    cmd = sudo ? "sudo #{command}" : command
    debug "Executing: #{cmd}"

    if quiet && !@debug
      stdout, stderr, status = Open3.capture3(cmd)
      raise "Command failed: #{cmd}\n#{stderr}" unless status.success?
      stdout
    else
      system(cmd) || raise("Command failed: #{cmd}")
    end
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def brew_quiet(command)
    execute("brew #{command}", quiet: !@debug)
  end

  def ci_or_noninteractive?
    ENV['CI'] || ENV['NONINTERACTIVE']
  end
end

class MacDevSetup
  attr_reader :dotfiles_repo, :dotfiles_dir, :home

  def initialize
    @debug = ENV['DEBUG'] == 'true'
    @dotfiles_repo = 'https://github.com/nateberkopec/dotfiles.git'
    @dotfiles_dir = File.expand_path('~/.dotfiles')
    @home = ENV['HOME']

    setup_signal_handlers
  end

  def run
    debug 'Starting macOS development environment setup...'

    step_params = {
      debug: @debug,
      dotfiles_repo: @dotfiles_repo,
      dotfiles_dir: @dotfiles_dir,
      home: @home
    }

    Step.all_steps.each do |step_class|
      step = step_class.new(**step_params)
      next unless step.should_run?
      step.run
    end

    puts 'Installation complete! Please restart your terminal for all changes to take effect.'
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end

  private

  def debug(message)
    puts message if @debug
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def setup_signal_handlers
    trap('EXIT') do
      debug 'Clearing SSH keys from agent...'
      system('ssh-add -D') if command_exists?('ssh-add')
    end
  end

end

class UpdateMacOSStep < Step
  def should_run?
    user_has_admin_rights? && STDIN.tty?
  end

  def run
    debug 'User has admin rights, checking for macOS updates...'
    execute('softwareupdate -i -a', sudo: true, quiet: true)
  end

  private

  def user_has_admin_rights?
    groups = `groups`.strip
    groups.include?('admin')
  end
end

class SetFontSmoothingStep < Step
  def run
    execute('defaults -currentHost write -g AppleFontSmoothing -int 0')
  end
end

class DisableDisplaysHaveSpacesStep < Step
  def run
    execute('defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer')
  end
end

class InstallHomebrewStep < Step
  def should_run?
    !command_exists?('brew')
  end

  def run
    debug 'Installing Homebrew...'
    execute('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')

    File.open(File.expand_path('~/.zprofile'), 'a') do |f|
      f.puts 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    end

    execute('eval "$(/opt/homebrew/bin/brew shellenv)"')
  end
end

class UpdateHomebrewStep < Step
  def run
    debug 'Updating Homebrew...'
    brew_quiet('update')
  end
end

class SetupSSHKeysStep < Step
  def should_run?
    if ci_or_noninteractive?
      debug 'Skipping 1Password SSH key setup in CI/non-interactive environment'
      return false
    end
    command_exists?('op')
  end

  def run
    debug '1Password CLI found, unlocking SSH key...'

    execute('op signin --account "my.1password.com"', quiet: true)

    ssh_key_json = execute('op item get "Main SSH Key (id_rsa)" --format=json', quiet: true)
    ssh_key_data = JSON.parse(ssh_key_json)
    private_key = ssh_key_data['fields'].find { |f| f['label'] == 'private key' }['value']

    IO.popen('ssh-add -', 'w') { |io| io.write(private_key) }
  end
end

class CloneDotfilesStep < Step
  def run
    if Dir.exist?(@dotfiles_dir)
      debug 'Dotfiles directory already exists, pulling latest changes...'
      Dir.chdir(@dotfiles_dir) { execute('git pull') }
    else
      debug 'Cloning dotfiles repository...'
      execute("git clone #{@dotfiles_repo} #{@dotfiles_dir}")
    end
  end
end

class InstallPackagesStep < Step
  def run
    packages = %w[zoxide ghostty bat gh rust mise direnv fish orbstack fontconfig libyaml coreutils]
    brew_quiet("install #{packages.join(' ')}")

    cask_packages = %w[nikitabobko/tap/aerospace github visual-studio-code raycast keycastr]
    brew_quiet("install --cask #{cask_packages.join(' ')}")

    install_1password
    install_arc_browser
  end

  private

  def install_1password
    unless Dir.exist?('/Applications/1Password.app')
      debug 'Installing 1Password...'
      brew_quiet('install --cask 1password 1password/tap/1password-cli')
    else
      debug '1Password is already installed, skipping...'
    end
  end

  def install_arc_browser
    unless Dir.exist?('/Applications/Arc.app')
      debug 'Installing Arc browser...'
      brew_quiet('install --cask arc')
    else
      debug 'Arc browser is already installed, skipping...'
    end
  end
end

class ConfigureApplicationsStep < Step
  def run
    configure_ghostty
    configure_aerospace
    configure_git
    configure_vscode
  end

  private

  def configure_ghostty
    ghostty_dir = File.expand_path('~/Library/Application Support/com.mitchellh.ghostty/')
    FileUtils.mkdir_p(ghostty_dir)
    FileUtils.cp("#{@dotfiles_dir}/ghostty/config", ghostty_dir)
  end

  def configure_aerospace
    debug 'Configuring Aerospace...'
    FileUtils.cp("#{@dotfiles_dir}/aerospace/.aerospace.toml",
                 File.expand_path('~'))
  end

  def configure_git
    debug 'Configuring Git global settings...'
    FileUtils.cp("#{@dotfiles_dir}/git/.gitconfig", File.expand_path('~/.gitconfig'))
  end

  def configure_vscode
    debug 'Configuring VSCode...'
    vscode_dir = File.expand_path('~/Library/Application Support/Code/User')
    FileUtils.mkdir_p(vscode_dir)

    FileUtils.cp("#{@dotfiles_dir}/vscode/settings.json", vscode_dir)
    FileUtils.cp("#{@dotfiles_dir}/vscode/keybindings.json", vscode_dir)

    install_vscode_extensions
  end

  def install_vscode_extensions
    extensions_file = "#{@dotfiles_dir}/vscode/extensions.txt"
    return unless File.exist?(extensions_file)

    debug 'Installing VSCode extensions...'
    installed_extensions = execute('code --list-extensions', quiet: true).split("\n")

    File.readlines(extensions_file).each do |extension|
      extension = extension.strip
      unless installed_extensions.include?(extension)
        debug "Installing VSCode extension: #{extension}"
        execute("code --install-extension #{extension}")
      else
        debug "VSCode extension already installed: #{extension}"
      end
    end
  end
end

class InstallRubyStep < Step
  def run
    debug 'Installing latest stable Ruby...'
    execute('mise use --global ruby@latest')
    execute('mise install ruby@latest')
  end
end

class SetFishDefaultShellStep < Step
  def should_run?
    fish_path = `which fish`.strip
    current_shell = execute('dscl . -read ~/ UserShell', quiet: true)
    !current_shell.include?(fish_path)
  end

  def run
    if ci_or_noninteractive?
      debug 'Skipping default shell change (chsh) in CI/non-interactive environment'
      return
    end

    fish_path = `which fish`.strip

    unless File.readlines('/etc/shells').any? { |line| line.strip == fish_path }
      debug 'Adding Fish to allowed shells...'
      execute("echo #{fish_path} | sudo tee -a /etc/shells", sudo: true)
    end

    debug 'Changing default shell to Fish...'
    execute("chsh -s #{fish_path}")
  end
end

class ConfigureFishStep < Step
  def run
    debug 'Setting up Fish configuration...'
    fish_config_dir = File.expand_path('~/.config/fish')
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp("#{@dotfiles_dir}/fish/config.fish", fish_config_dir)
    FileUtils.cp_r("#{@dotfiles_dir}/fish/functions", fish_config_dir)

    install_oh_my_fish
  end

  private

  def install_oh_my_fish
    omf_dir = File.expand_path('~/.local/share/omf')
    unless Dir.exist?(omf_dir)
      debug 'Installing oh-my-fish...'
      execute('curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install')
      execute('fish -c "fish install --noninteractive"')
      FileUtils.rm('install')
    else
      debug 'oh-my-fish already installed, skipping...'
    end

    debug 'Configuring oh-my-fish...'
    omf_config_dir = File.expand_path('~/.config/omf')
    FileUtils.mkdir_p(omf_config_dir)
    FileUtils.cp_r(Dir.glob("#{@dotfiles_dir}/omf/*"), omf_config_dir)

    execute('fish -c "omf install"')
  end
end

class InstallFontsStep < Step
  def should_run?
    font_dir = "#{@dotfiles_dir}/fonts"
    return false unless Dir.exist?(font_dir)
    
    font_files = Dir.glob("#{font_dir}/*.ttf")
    return false if font_files.empty?
    
    installed_fonts = execute('fc-list', quiet: true)
    
    font_files.any? do |font_path|
      font_name = File.basename(font_path)
      !installed_fonts.include?(font_name)
    end
  end

  def run
    if ci_or_noninteractive?
      debug 'Skipping font installation (requires GUI) in CI/non-interactive environment'
      return
    end

    font_dir = "#{@dotfiles_dir}/fonts"
    
    Dir.glob("#{font_dir}/*.ttf").each do |font_path|
      font_name = File.basename(font_path)
      debug "Installing font: #{font_name}"
      execute("open #{Shellwords.escape(font_path)}")
    end
  end
end

if __FILE__ == $0
  MacDevSetup.new.run
end
