require "time"
%w[versions sources release_notes_upstream release_notes manifests candidates changed_pins report report_checks lock_provenance transport].each do |name|
  require_relative "dependency_factory/#{name}"
end

module DependencyFactory
  ROOT = File.expand_path("../..", __dir__)
  CONFIG_PATH = "config/dependency-updater.yml"
  DEPENDENCY_PATHS = %w[.mise.toml Gemfile.lock config/config.yml config/dependency-updater.yml config/mise.version files/home/.config/mise/config.toml files/home/.config/mise/mise.lock files/home/.pi/agent/settings.json].freeze
end
