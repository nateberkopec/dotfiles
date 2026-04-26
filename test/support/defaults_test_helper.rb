module DefaultsTestHelper
  def flatten_defaults_config(settings_hash)
    settings_hash.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end

  def stub_defaults(entries, overrides: {}, status_overrides: {})
    entries.each do |domain, key, value|
      domain_flag = (domain == "NSGlobalDomain") ? "-g" : domain
      override_value = overrides.fetch(domain, {}).fetch(key, value)
      exit_status = status_overrides.fetch([domain, key], 0)
      command = defaults_read_command(domain_flag, key)
      @fake_system.stub_command(command, override_value.to_s, exit_status: exit_status)
    end
  end
end
