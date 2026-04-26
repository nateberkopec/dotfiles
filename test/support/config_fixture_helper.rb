require "yaml"

module ConfigFixtureHelper
  def write_config(_name, data)
    path = config_yml_path
    @fake_system.mkdir_p(File.dirname(path))
    existing = begin
      YAML.safe_load(@fake_system.read_file(path)) || {}
    rescue Errno::ENOENT
      {}
    end
    merged = existing.merge(data)
    content = YAML.dump(merged)
    @fake_system.stub_file_content(path, content)
    path
  end

  def read_config(path)
    YAML.safe_load(@fake_system.read_file(path))
  end

  def reset_step_cache(step, *ivar_names)
    ivar_names.each do |ivar|
      next unless step.instance_variable_defined?(ivar)
      step.remove_instance_variable(ivar)
    end
    step.config.instance_variable_set(:@config, nil) if step.respond_to?(:config)
  end

  private

  def config_yml_path
    File.join(@dotfiles_dir, "config", "config.yml")
  end
end
