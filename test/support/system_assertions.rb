module SystemAssertions
  [:assert, :refute].product([:execute]).each do |expectation, operation|
    define_method("#{expectation}_executed") do |command, quiet: true, message: nil|
      verify_execution(operation, command, quiet: quiet, message: message, expectation: expectation)
    end
  end

  def assert_executed!(command, quiet: true, message: nil)
    verify_execution(:execute!, command, quiet: quiet, message: message, expectation: :assert)
  end

  def defaults_read_command(domain, key = nil, global: false)
    if global
      "defaults read -g #{key}"
    elsif key
      "defaults read #{domain} #{key}"
    else
      "defaults read #{domain}"
    end
  end

  def defaults_write_command(domain, key, value)
    domain_flag = (domain == "NSGlobalDomain") ? "-g" : domain
    "defaults write #{domain_flag} #{key} #{defaults_type_flag(value)} #{value}"
  end

  def stub_defaults_reads(domain, pairs, global: false)
    pairs.each do |key, value|
      command = defaults_read_command(domain, key, global: global)
      @fake_system.stub_command(command, value.to_s, exit_status: 0)
    end
  end

  def assert_defaults_written(entries)
    entries.each do |domain, key, value|
      assert_executed(defaults_write_command(domain, key, value))
    end
  end

  def assert_command_run(operation, *args)
    verify_operation(operation, args, :assert)
  end

  def refute_command_run(operation, *args)
    verify_operation(operation, args, :refute)
  end

  private

  def defaults_type_flag(value)
    case value
    when Integer
      "-int"
    when Float
      "-float"
    when TrueClass, FalseClass
      "-bool"
    else
      "-string"
    end
  end

  def verify_execution(operation, command, quiet:, message:, expectation:)
    default_message =
      if expectation == :assert
        "Expected command `#{command}` to be executed via #{operation} (quiet: #{quiet})"
      else
        "Did not expect command `#{command}` to be executed via #{operation} (quiet: #{quiet})"
      end
    message ||= default_message
    send(expectation, @fake_system.received_operation?(operation, command, {quiet: quiet}), message)
  end

  def verify_operation(operation, args, expectation)
    default_message =
      if expectation == :assert
        "Expected #{@fake_system.inspect} to receive #{operation} with #{args.inspect}"
      else
        "Did not expect #{@fake_system.inspect} to receive #{operation} with #{args.inspect}"
      end
    send(expectation, @fake_system.received_operation?(operation, *args), default_message)
  end
end
