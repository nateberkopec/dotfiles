class InstallRubyStep < Step
  def run
    debug 'Installing latest stable Ruby...'
    execute('mise use --global ruby@latest')
    execute('mise install ruby@latest')
  end

  def complete?
    output = execute('mise current ruby', capture_output: true, quiet: true)
    !output.strip.empty?
  rescue
    false
  end
end