class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step
  def run
    setting_entries.each do |domain, key, value|
      domain_flag = domain_flag_for(domain)
      type_flag = type_flag_for(value)
      execute("defaults write #{domain_flag} #{key} #{type_flag} #{value}")
    end
    execute("killall Dock")
    execute("killall Finder")
  end

  def complete?
    setting_entries.all? do |domain, key, expected_value|
      defaults_read_equals?(build_read_command(domain, key), normalize_value(expected_value))
    end
  end

  def update
    updated_settings = setting_entries.group_by(&:first).transform_values do |entries|
      entries.filter_map { |domain, key, _value|
        read_command = build_read_command(domain, key)
        output, status = execute(read_command, quiet: true)
        [key, parse_value(output)] if status == 0
      }.to_h
    end

    content = {"animation_settings" => updated_settings}.to_yaml
    @system.write_file(animations_config_path, content)
  end

  private

  def animation_settings
    @config.load_config("animations.yml").fetch("animation_settings", {})
  end

  def setting_entries
    animation_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end

  def animations_config_path
    @system.path_join(@dotfiles_dir, "config", "animations.yml")
  end

  def domain_flag_for(domain)
    (domain == "NSGlobalDomain") ? "-g" : domain
  end

  def build_read_command(domain, key)
    domain_flag = domain_flag_for(domain)
    "defaults read #{domain_flag} #{key}"
  end

  def type_flag_for(value)
    case value
    when 0, 1
      "-int"
    when Float
      "-float"
    else
      "-int"
    end
  end

  def normalize_value(value)
    value.to_s
  end

  def parse_value(output)
    return output.to_f if output.include?(".")
    output.to_i
  end
end
