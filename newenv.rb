#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'open3'
require 'shellwords'

class MacDevSetup
  def initialize
    @debug = ENV['DEBUG'] == 'true'
    @dotfiles_repo = 'https://github.com/nateberkopec/dotfiles.git'
    @dotfiles_dir = File.expand_path('~/.dotfiles')
    @home = ENV['HOME']

    setup_signal_handlers
  end

  def run
    debug 'Starting macOS development environment setup...'

    update_macos if user_has_admin_rights?
    set_font_smoothing
    disable_displays_have_spaces
    install_homebrew
    setup_ssh_keys
    clone_dotfiles
    install_packages
    configure_applications
    install_ruby
    setup_fish_shell
    install_fonts

    puts 'Installation complete! Please restart your terminal for all changes to take effect.'
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end

  private

  def debug(message)
    puts message if @debug
  end

  def execute(command, quiet: !@debug, sudo: false)
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

  def user_has_admin_rights?
    groups = `groups`.strip
    groups.include?('admin')
  end

  def update_macos
    if user_has_admin_rights?
      debug 'User has admin rights, checking for macOS updates...'
      execute('softwareupdate -i -a', sudo: true, quiet: true)
    else
      debug "User doesn't have admin rights, skipping macOS updates..."
    end
  end

  def set_font_smoothing
    execute('defaults -currentHost write -g AppleFontSmoothing -int 0')
  end

  def disable_displays_have_spaces
    execute('defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer')
  end

  def install_homebrew
    unless command_exists?('brew')
      debug 'Installing Homebrew...'
      execute('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')

      File.open(File.expand_path('~/.zprofile'), 'a') do |f|
        f.puts 'eval "$(/opt/homebrew/bin/brew shellenv)"'
      end

      execute('eval "$(/opt/homebrew/bin/brew shellenv)"')
    else
      debug 'Homebrew already installed, updating...'
      brew_quiet('update')
    end
  end

  def brew_quiet(command)
    execute("brew #{command}", quiet: !@debug)
  end

  def setup_ssh_keys
    return unless command_exists?('op')

    debug '1Password CLI found, unlocking SSH key...'

    execute('op signin --account "my.1password.com"', quiet: true)

    unless command_exists?('jq')
      debug 'Installing jq...'
      brew_quiet('install jq')
    else
      debug 'jq already installed'
    end

    ssh_key_json = execute('op item get "Main SSH Key (id_rsa)" --format=json', quiet: true)
    ssh_key_data = JSON.parse(ssh_key_json)
    private_key = ssh_key_data['fields'].find { |f| f['label'] == 'private key' }['value']

    IO.popen('ssh-add -', 'w') { |io| io.write(private_key) }
  rescue StandardError => e
    puts e
    puts e.message
    raise 'Failed to set up SSH key from 1Password. Ensure the 1Password CLI is installed and configured correctly.' unless @debug
  end

  def setup_signal_handlers
    trap('EXIT') do
      debug 'Clearing SSH keys from agent...'
      system('ssh-add -D') if command_exists?('ssh-add')
    end
  end

  def clone_dotfiles
    if Dir.exist?(@dotfiles_dir)
      debug 'Dotfiles directory already exists, pulling latest changes...'
      Dir.chdir(@dotfiles_dir) { execute('git pull') }
    else
      debug 'Cloning dotfiles repository...'
      execute("git clone #{@dotfiles_repo} #{@dotfiles_dir}")
    end
  end

  def install_packages
    packages = %w[zoxide ghostty bat gh rust mise direnv fish orbstack fontconfig libyaml coreutils]
    brew_quiet("install #{packages.join(' ')}")

    cask_packages = %w[nikitabobko/tap/aerospace github visual-studio-code raycast keycastr]
    brew_quiet("install --cask #{cask_packages.join(' ')}")

    install_1password
    install_arc_browser
  end

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

  def configure_applications
    configure_ghostty
    configure_aerospace
    configure_git
    configure_vscode
  end

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

  def install_ruby
    debug 'Installing latest stable Ruby...'
    execute('mise use --global ruby@latest')
    execute('mise install ruby@latest')
  end

  def setup_fish_shell
    fish_path = `which fish`.strip

    unless File.readlines('/etc/shells').any? { |line| line.strip == fish_path }
      debug 'Adding Fish to allowed shells...'
      execute("echo #{fish_path} | sudo tee -a /etc/shells", sudo: true)
    end

    current_shell = execute('dscl . -read ~/ UserShell', quiet: true)
    unless current_shell.include?(fish_path)
      debug 'Changing default shell to Fish...'
      execute("chsh -s #{fish_path}")
    else
      debug 'Fish is already the default shell, skipping...'
    end

    configure_fish
  end

  def configure_fish
    debug 'Setting up Fish configuration...'
    fish_config_dir = File.expand_path('~/.config/fish')
    FileUtils.mkdir_p(fish_config_dir)

    FileUtils.cp("#{@dotfiles_dir}/fish/config.fish", fish_config_dir)
    FileUtils.cp_r("#{@dotfiles_dir}/fish/functions", fish_config_dir)

    install_oh_my_fish
  end

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

  def install_fonts
    font_dir = "#{@dotfiles_dir}/fonts"
    return unless Dir.exist?(font_dir)

    installed_fonts = execute('fc-list', quiet: true)

    Dir.glob("#{font_dir}/*.ttf").each do |font_path|
      font_name = File.basename(font_path)
      unless installed_fonts.include?(font_name)
        debug "Installing font: #{font_name}"
        execute("open #{Shellwords.escape(font_path)}")
      else
        debug "Font #{font_name} is already installed, skipping..."
      end
    end
  end
end

if __FILE__ == $0
  MacDevSetup.new.run
end
