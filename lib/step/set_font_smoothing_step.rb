class SetFontSmoothingStep < Step
  def run
    debug 'Disabling font smoothing for better text rendering...'
    execute('defaults -currentHost write -g AppleFontSmoothing -int 0')
  end

  def complete?
    output = execute('defaults -currentHost read -g AppleFontSmoothing', capture_output: true, quiet: true)
    output.strip == '0'
  rescue
    false
  end
end
