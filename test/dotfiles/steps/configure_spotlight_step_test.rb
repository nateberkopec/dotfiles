require "test_helper"

class ConfigureSpotlightStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureSpotlightStep

  def test_complete_by_default
    assert_complete
  end

  def test_run_installs_root_owned_controller_and_daemon
    write_spotlight_config
    stub_controller_template

    step.run

    assert_executed("sudo install -d -o root -g wheel -m 755 /usr/local/libexec", quiet: false)
    assert_executed("sudo install -d -o root -g wheel -m 700 /var/db/dotfiles-spotlight", quiet: false)
    assert_executed("sudo install -o root -g wheel -m 755 #{controller_source_path} #{controller_path}", quiet: false)
    assert_executed("sudo install -o root -g wheel -m 644 #{plist_source_path} #{plist_path}", quiet: false)
    assert_executed("sudo launchctl bootstrap system #{plist_path}", quiet: false)
  end

  def test_complete_when_installed_files_match
    write_spotlight_config
    stub_controller_template
    write_current_files

    assert_complete
  end

  def test_disabled_configuration_uninstalls_existing_controller
    write_spotlight_config("enabled" => false)
    stub_controller_template
    @fake_system.write_file(controller_path, "old")

    assert_should_run
    step.run

    command = @fake_system.operations.find do |operation|
      operation.first == :execute && operation.flatten.join(" ").include?("launchctl bootout system")
    end
    assert command, "Expected controller uninstall command"
    refute @fake_system.file_exist?(controller_source_path)
  end

  def test_failed_uninstall_is_reported_by_validation
    write_spotlight_config("enabled" => false)
    stub_controller_template
    @fake_system.write_file(controller_path, "old")
    command = Dotfiles::Command.prepend(step.send(:uninstall_command), "sudo")
    @fake_system.stub_command(command, "permission denied", 1)

    step.run

    errors = step.collect_errors
    assert_includes errors, "Spotlight controller uninstall command failed"
    assert_includes errors, "Spotlight controller artifacts remain after uninstall"
  end

  def test_disabled_configuration_is_complete_without_artifacts
    write_spotlight_config("enabled" => false)
    stub_controller_template

    assert_complete
  end

  def test_generated_controller_shell_quotes_paths_with_spaces
    write_spotlight_config(
      "volumes" => ["/", "/Volumes/External SSD"],
      "exclusions" => ["~/Documents/Code Archive"]
    )
    stub_controller_template

    controller = step.send(:controller_content)

    assert_includes controller, "set -- / /Volumes/External\\ SSD"
    assert_includes controller, "set -- /tmp/home/Documents/Code\\ Archive"
  end

  private

  def write_spotlight_config(overrides = {})
    settings = {
      "enabled" => true,
      "volumes" => ["/", "/System/Volumes/Data"],
      "exclusions" => ["~/Documents/Code.nosync", "~/src"],
      "check_interval_seconds" => 60
    }.merge(overrides)
    write_config("spotlight", "spotlight_settings" => settings)
  end

  def stub_controller_template
    @fake_system.stub_file_content(
      "/tmp/dotfiles/files/spotlight/spotlight-controller.sh",
      "set -- __VOLUMES__\nset -- __VOLUMES__\nset -- __EXCLUSIONS__\nSTATE=__STATE_DIR__\n"
    )
  end

  def write_current_files
    controller = step.send(:controller_content)
    plist = step.send(:plist_content)
    @fake_system.write_file(controller_source_path, controller)
    @fake_system.write_file(controller_path, controller)
    @fake_system.write_file(plist_path, plist)
  end

  def controller_source_path
    "/tmp/home/.local/share/spotlight/spotlight-controller"
  end

  def plist_source_path
    "/tmp/home/.local/share/spotlight/com.user.spotlight-controller.plist"
  end

  def controller_path
    "/usr/local/libexec/dotfiles-spotlight-controller"
  end

  def plist_path
    "/Library/LaunchDaemons/com.user.spotlight-controller.plist"
  end
end
