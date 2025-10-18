$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "dotfiles"))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "dotfiles", "steps"))

require "dotfiles/step"
Dir.glob(File.join(File.dirname(__FILE__), "dotfiles", "steps", "*.rb")).each { |file| require File.basename(file, ".rb") }
