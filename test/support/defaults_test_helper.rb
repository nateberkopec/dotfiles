module DefaultsTestHelper
  def flatten_defaults_config(settings_hash)
    settings_hash.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end

  def assert_defaults_read_count(expected_count)
    read_commands = @fake_system.operations.select { |op| op[0] == :execute && op[1].start_with?("defaults read") }
    assert_equal expected_count, read_commands.size
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
