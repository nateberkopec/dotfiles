# standard:disable Dotfiles/BanFileSystemClasses -- black-box mise task test requires real temporary files
require "test_helper"
require "open3"
require "tmpdir"
require "toml-rb"

class SpotlightMiseTaskTest < Minitest::Test
  def test_pause_duration_is_forwarded_by_mise
    Dir.mktmpdir do |tmp|
      fake_controller = File.join(tmp, "controller")
      File.write(fake_controller, "#!/bin/sh\nprintf '<%s>\\n' \"$@\"\n")
      File.chmod(0o755, fake_controller)
      task = managed_config.fetch("tasks").fetch("spotlight:pause")
      run = task.fetch("run").sub("sudo /usr/local/libexec/dotfiles-spotlight-controller", fake_controller)
      config = File.join(tmp, "config.toml")
      File.write(config, "[tasks.\"spotlight:pause\"]\nrun = #{run.inspect}\n")

      output, status = Open3.capture2e({"MISE_CONFIG_FILE" => config}, "mise", "run", "spotlight:pause", "--", "30m", chdir: tmp)

      assert status.success?, output
      assert_equal ["<pause>", "<30m>"], output.lines.grep(/^</).map(&:strip)
    end
  end

  private

  def managed_config
    TomlRB.load_file(File.join(__dir__, "..", "files", "home", ".config", "mise", "config.toml"))
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
