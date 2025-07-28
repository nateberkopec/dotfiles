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

  def complete?
    command_exists?('brew')
  end
end