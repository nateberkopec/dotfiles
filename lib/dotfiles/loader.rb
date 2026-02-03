class Dotfiles
  module Loader
    def self.load!
      load_path
      require_core
      require_steps
      require_runtime
    end

    def self.load_path
      $LOAD_PATH.unshift(File.expand_path(__dir__))
    end

    def self.require_core
      require "config"
      require "system_adapter"
      require "step"
      require "step/defaultable"
      require "step/sudoable"
      require "step/protectable"
    end

    def self.require_steps
      step_files.each { |file| require file }
    end

    def self.step_files
      Dotfiles::SystemAdapter.new.glob(File.join(__dir__, "steps", "**", "*.rb")).sort
    end

    def self.require_runtime
      require "runner"
    end
  end
end
