class SetFontSmoothingStep < Step
  def run
    debug "Disabling font smoothing for better text rendering..."
    execute("defaults -currentHost write -g AppleFontSmoothing -int 0")
  end

  def complete?
    defaults_read_equals?("defaults -currentHost read -g AppleFontSmoothing", "0")
  end
end
