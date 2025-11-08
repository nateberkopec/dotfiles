require "yaml"

module ConfigFixtureHelper
  def write_config(name, data)
    path = File.join(@dotfiles_dir, "config", "#{name}.yml")
    @fake_system.mkdir_p(File.dirname(path))
    content = data.is_a?(String) ? data : YAML.dump(data)
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
  end

  def expect_config_write(name)
    write_op = @fake_system.operations.reverse.find do |op|
      op[0] == :write_file && op[1].end_with?("/config/#{name}.yml")
    end
    refute_nil write_op, "Expected update to write config/#{name}.yml"
    yield YAML.safe_load(write_op[2])
  end
end
