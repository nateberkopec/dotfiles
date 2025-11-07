class Dotfiles::Step::ConfigureTrackpadStep < Dotfiles::Step
  def run
    setting_entries.each do |domain, key, value|
      domain_flag = domain_flag_for(domain)
      execute("defaults write #{domain_flag} #{key} -int #{value}")
    end
  end

  def complete?
    setting_entries.all? do |domain, key, expected_value|
      defaults_read_equals?(build_read_command(domain, key), expected_value.to_s)
    end
  end

  def update
    updated_settings = setting_entries.group_by(&:first).transform_values do |entries|
      entries.filter_map { |domain, key, _value|
        read_command = build_read_command(domain, key)
        output, status = execute(read_command, quiet: true)
        [key, output.to_i] if status == 0
      }.to_h
    end

    content = {"trackpad_settings" => updated_settings}.to_yaml
    @system.write_file(trackpad_config_path, content)
  end

  private

  def trackpad_settings
    @config.load_config("trackpad.yml").fetch("trackpad_settings", {})
  end

  def setting_entries
    trackpad_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end

  def trackpad_config_path
    @system.path_join(@dotfiles_dir, "config", "trackpad.yml")
  end

  def domain_flag_for(domain)
    (domain == "NSGlobalDomain") ? "-g" : domain
  end

  def build_read_command(domain, key)
    domain_flag = domain_flag_for(domain)
    "defaults read #{domain_flag} #{key}"
  end
end
