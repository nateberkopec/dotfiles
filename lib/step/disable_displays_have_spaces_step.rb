class DisableDisplaysHaveSpacesStep < Step
  def run
    debug "Configuring Spaces to span across multiple displays..."
    execute("defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer")
  end

  def complete?
    output = execute("defaults read com.apple.spaces spans-displays", capture_output: true, quiet: true)
    output.strip == "1"
  rescue
    false
  end
end
