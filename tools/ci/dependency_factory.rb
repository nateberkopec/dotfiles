require "time"
%w[versions sources manifests candidates changed_pins report report_checks rubric_checks lock_provenance].each do |name|
  require_relative "dependency_factory/#{name}"
end

module DependencyFactory
  ROOT = File.expand_path("../..", __dir__)
  CONFIG_PATH = "config/dependency-updater.yml"
end
