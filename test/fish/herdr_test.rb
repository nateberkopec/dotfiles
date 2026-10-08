require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class HerdrRoutingTest < Minitest::Test
  def setup
    @home = Dir.mktmpdir("herdr-routing-")
    FileUtils.mkdir_p(["bin", ".dotfiles/lib", "Documents/Code.nosync/personal/gtd/notes", "Documents/Code.nosync/business/client_notes", ".local/share/dotfiles"].map { |path| File.join(@home, path) })
    File.write(File.join(@home, "bin/herdr"), "#!/bin/sh\nprintf 'plain:%s\\n' \"$*\"\n")
    FileUtils.chmod(0o755, File.join(@home, "bin/herdr"))
    File.write(File.join(@home, ".local/share/dotfiles/herdr-launch.rb"), "puts 'personal'\n")
    @env = {"HOME" => @home, "HERDR_ENV" => nil, "PATH" => "#{@home}/bin:#{ENV.fetch("PATH")}", "SOURCE" => File.expand_path("../../files/home/.config/fish/functions/herdr.fish", __dir__)}
  end

  def teardown
    FileUtils.remove_entry(@home)
  end

  def launch(directory, *arguments)
    stdout, stderr, status = Open3.capture3(@env.merge("TARGET" => File.join(@home, directory)), "fish", "--no-config", "-c", 'source "$SOURCE"; cd "$TARGET"; herdr $argv', "--", *arguments)
    assert status.success?, stderr
    stdout.strip
  end

  def test_home_gtd_and_dotfiles_launch_the_personal_profile
    [".", ".dotfiles", ".dotfiles/lib", "Documents/Code.nosync/personal/gtd", "Documents/Code.nosync/personal/gtd/notes"].each do |directory|
      assert_equal "personal", launch(directory)
    end
  end

  def test_business_and_other_home_descendants_keep_the_normal_profile
    ["Documents/Code.nosync/business/client_notes", "Documents/Code.nosync/personal", ".local"].each do |directory|
      assert_equal "plain:", launch(directory)
    end
  end

  def test_explicit_session_remote_and_api_commands_are_not_redirected
    assert_equal "plain:--session other", launch(".", "--session", "other")
    assert_equal "plain:--remote cookpad", launch(".dotfiles", "--remote", "cookpad")
    assert_equal "plain:workspace list", launch("Documents/Code.nosync/personal/gtd", "workspace", "list")
  end

  def test_commands_from_inside_herdr_keep_the_inherited_context
    @env["HERDR_ENV"] = "1"
    assert_equal "plain:", launch(".")
  end

  def test_similarly_named_directories_do_not_match
    FileUtils.mkdir_p(File.join(@home, ".dotfiles-other"))
    FileUtils.mkdir_p(File.join(@home, "Documents/Code.nosync/personal/gtd-other"))
    assert_equal "plain:", launch(".dotfiles-other")
    assert_equal "plain:", launch("Documents/Code.nosync/personal/gtd-other")
  end
end
