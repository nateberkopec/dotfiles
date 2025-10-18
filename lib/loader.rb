$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "step"))

require "config_loader"
require "step"
Dir.glob(File.join(File.dirname(__FILE__), "step", "*.rb")).each { |file| require File.basename(file, ".rb") }
