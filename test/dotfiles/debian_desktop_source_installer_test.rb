require "test_helper"
class DebianDesktopSourceInstallerTest < Minitest::Test
  class FailingSystem < FakeSystemAdapter
    def initialize(fail_at)
      super()
      @fail_at = fail_at
      @calls = 0
    end

    def execute(command, quiet: true)
      result = super
      @calls += 1
      (@calls == @fail_at) ? ["failed", 1] : result
    end
  end

  def test_install_does_nothing_by_default
    refute Dotfiles::DebianDesktopSourceInstaller.new(system: @fake_system).install
  end

  def test_install_adds_missing_keyring_and_source_list
    assert Dotfiles::DebianDesktopSourceInstaller.new(system: @fake_system).install(source)
    assert_equal "deb https://example.invalid stable main\n", @fake_system.operations.find { |operation| operation.first == :write_file }.last
  end

  def test_install_is_idempotent
    @fake_system.stub_file_content("/usr/share/keyrings/example-archive-keyring.gpg", "key")
    @fake_system.stub_file_content("/etc/apt/sources.list.d/example.list", source["line"])
    assert Dotfiles::DebianDesktopSourceInstaller.new(system: @fake_system).install(source)
    assert_equal [0, 0], [:execute, :write_file].map { |operation| @fake_system.operation_count(operation) }
  end

  def test_install_stops_and_cleans_up_after_each_command_failure
    (1..4).each do |fail_at|
      system = FailingSystem.new(fail_at)
      refute Dotfiles::DebianDesktopSourceInstaller.new(system: system).install(source)
      assert_equal [fail_at, 3], [:execute, :rm_rf].map { |operation| system.operation_count(operation) }
    end
  end

  def source
    {"name" => "example", "key_url" => "https://example.invalid/key", "line" => "deb https://example.invalid stable main"}
  end
end
