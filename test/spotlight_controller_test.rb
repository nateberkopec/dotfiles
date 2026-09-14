# standard:disable Dotfiles/BanFileSystemClasses -- black-box controller test requires real temporary files
require "test_helper"
require "open3"
require "tmpdir"

class SpotlightControllerTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    @bin = File.join(@tmp, "bin")
    Dir.mkdir(@bin)
    File.write(File.join(@tmp, "power"), "AC Power")
    File.write(File.join(@tmp, "status"), "enabled")
    install_fake_commands
    install_controller
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_battery_disables_indexing
    File.write(File.join(@tmp, "power"), "Battery Power")

    run_controller("reconcile")

    assert_equal "off\noff\n", File.read(File.join(@tmp, "changes"))
  end

  def test_ac_enables_indexing
    File.write(File.join(@tmp, "status"), "disabled")

    run_controller("reconcile")

    assert_equal "on\non\n", File.read(File.join(@tmp, "changes"))
  end

  def test_pause_overrides_ac_and_resume_honors_battery
    run_controller("pause", "24h")
    assert_equal "off\noff\n", File.read(File.join(@tmp, "changes"))

    File.write(File.join(@tmp, "power"), "Battery Power")
    File.write(File.join(@tmp, "changes"), "")
    run_controller("resume")

    assert_equal "off\noff\n", File.read(File.join(@tmp, "changes"))
    refute File.exist?(File.join(@tmp, "state", "pause-until"))
  end

  def test_expired_pause_is_removed_before_ac_policy
    state = File.join(@tmp, "state")
    Dir.mkdir(state)
    File.write(File.join(state, "pause-until"), "999\n")
    File.write(File.join(@tmp, "status"), "disabled")

    run_controller("reconcile")

    refute File.exist?(File.join(state, "pause-until"))
    assert_equal "on\non\n", File.read(File.join(@tmp, "changes"))
  end

  def test_reconcile_is_idempotent
    run_controller("reconcile")

    refute File.exist?(File.join(@tmp, "changes"))
  end

  def test_invalid_duration_fails_without_changing_state
    _output, status = run_controller("pause", "later", success: false)

    refute status.success?
    refute Dir.exist?(File.join(@tmp, "state"))
  end

  def test_unknown_power_source_is_an_error
    File.write(File.join(@tmp, "power"), "Unknown")

    output, status = run_controller("reconcile", success: false)

    refute status.success?
    assert_includes output, "Unable to determine power source"
  end

  private

  def install_controller
    source = File.read(File.join(__dir__, "..", "files", "spotlight", "spotlight-controller.sh"))
    source.sub!("PATH=/usr/bin:/bin:/usr/sbin:/sbin", "PATH=#{@bin}")
    source.sub!("STATE_DIR=__STATE_DIR__", "STATE_DIR=#{File.join(@tmp, "state")}")
    source.sub!("__VOLUMES__", "/ /System/Volumes/Data")
    source.sub!("__EXCLUSIONS__", "/tmp/code /tmp/src")
    source.sub!(/require_root\(\) \{.*?^\}/m, "require_root() { :; }")
    @controller = File.join(@tmp, "controller")
    File.write(@controller, source)
    File.chmod(0o755, @controller)
  end

  def install_fake_commands
    write_command("id", "echo 0")
    write_command("pmset", "echo \"Now drawing from '$(cat #{@tmp}/power)'\"")
    write_command("date", 'if [ "${1:-}" = "+%s" ]; then echo 1000; else echo "test date"; fi')
    write_command("head", "/usr/bin/head \"$@\"")
    write_command("cat", "/bin/cat \"$@\"")
    write_command("mkdir", "/bin/mkdir \"$@\"")
    write_command("chmod", "/bin/chmod \"$@\"")
    write_command("mv", "/bin/mv \"$@\"")
    write_command("rm", "/bin/rm \"$@\"")
    write_command("mdutil", <<~SH)
      if [ "$1" = "-s" ]; then
        echo "$2: Indexing $(cat #{@tmp}/status)."
      elif [ "$1" = "-i" ]; then
        echo "$2" >> #{@tmp}/changes
      elif [ "$1" = "-P" ]; then
        echo '<plist><dict><key>Exclusions</key><array/></dict></plist>'
      fi
    SH
  end

  def write_command(name, body)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end

  def run_controller(*args, success: true)
    output, status = Open3.capture2e(@controller, *args)
    assert status.success?, output if success
    [output, status]
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
