require "test_helper"

class ConfigureSpotlightExclusionsStepTest < StepTestCase
  step_class Dotfiles::Step::ConfigureSpotlightExclusionsStep

  def test_run_disables_configured_volumes
    write_spotlight_config("disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing enabled.")

    step.run

    assert_executed("sudo mdutil -i off /Volumes/Archive", quiet: false)
  end

  def test_run_expands_tilde_for_disabled_volumes
    write_spotlight_config("disabled_volumes" => ["~/Documents/Code.nosync"])
    stub_df_mount(expanded_home_code_dir, "/System/Volumes/Data")
    @fake_system.mkdir_p(expanded_home_code_dir)

    step.run

    assert @fake_system.file_exist?(File.join(expanded_home_code_dir, ".metadata_never_index"))
  end

  def test_incomplete_when_indexing_enabled_on_disabled_volume
    write_spotlight_config("disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing enabled.")

    assert_incomplete
  end

  def test_complete_when_indexing_disabled_on_disabled_volume
    write_spotlight_config("disabled_volumes" => ["/Volumes/Archive"])
    stub_df_mount("/Volumes/Archive", "/Volumes/Archive")
    stub_mdutil_status("/Volumes/Archive", "Indexing disabled.")

    assert_complete
  end

  def test_incomplete_when_metadata_never_index_missing
    write_spotlight_config("disabled_volumes" => ["~/Documents/Code.nosync"])
    stub_df_mount(expanded_home_code_dir, "/System/Volumes/Data")
    @fake_system.mkdir_p(expanded_home_code_dir)

    assert_incomplete
  end

  def test_complete_when_no_disabled_volumes
    write_spotlight_config("disabled_volumes" => [])
    assert_complete
  end

  private

  def write_spotlight_config(overrides = {})
    settings = {"disabled_volumes" => []}.merge(overrides)
    write_config("spotlight", "spotlight_settings" => settings)
  end

  def stub_mdutil_status(volume, status_line)
    @fake_system.stub_command("mdutil -s #{volume}", "#{volume}:\n\t#{status_line}", 0)
  end

  def stub_df_mount(path, mount_point)
    output = <<~OUT
      Filesystem 512-blocks Used Available Capacity iused ifree %iused Mounted on
      /dev/disk3s1s1 3896910480 1 1 1% 1 1 1% #{mount_point}
    OUT
    @fake_system.stub_command("df -P #{path}", output, 0)
  end

  def expanded_home_code_dir
    File.join(@home, "Documents", "Code.nosync")
  end
end
