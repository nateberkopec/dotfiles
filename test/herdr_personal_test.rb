require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class HerdrPersonalTest < Minitest::Test
  def setup
    @home = Dir.mktmpdir("herdr-personal-")
    @source = File.expand_path("../files/home", __dir__)
    @launcher = File.join(@source, ".local/share/dotfiles/herdr-launch.rb")
    FileUtils.mkdir_p([File.join(@home, ".config/herdr-personal/herdr"), File.join(@home, ".dotfiles"), File.join(@home, "Documents/Code.nosync/personal/gtd")])
    FileUtils.cp(File.join(@source, ".config/herdr-personal/herdr/spaces.json"), File.join(@home, ".config/herdr-personal/herdr/spaces.json"))
    FileUtils.mkdir_p(File.join(@home, "bin"))
    FileUtils.cp(File.expand_path("fixtures/herdr_personal/herdr", __dir__), File.join(@home, "bin/herdr"))
    FileUtils.chmod(0o755, File.join(@home, "bin/herdr"))
    @env = {"HOME" => @home, "HERDR_ENV" => nil, "HERDR_SOCKET_PATH" => "/wrong/socket", "HERDR_CONFIG_PATH" => "/wrong/config", "XDG_CONFIG_HOME" => nil, "XDG_STATE_HOME" => nil, "PATH" => "#{@home}/bin:#{ENV.fetch("PATH")}"}
  end

  def teardown
    FileUtils.remove_entry(@home)
  end

  def run_launcher(*arguments)
    Open3.capture3(@env, RbConfig.ruby, @launcher, *arguments)
  end

  def spaces
    JSON.parse(File.read(File.join(@home, "workspaces.json")))
  end

  def test_launches_and_syncs_the_isolated_profile_without_duplicates_or_resetting_panes
    stdout, stderr, status = run_launcher
    assert status.success?, stderr
    assert_includes stdout, "attached personal"
    assert_equal ["GTD", "Dotfiles", "General"], spaces.map { |space| space.fetch("label") }
    assert_equal ["#{@home}/Documents/Code.nosync/personal/gtd", "#{@home}/.dotfiles", @home], spaces.map { |space| space.fetch("cwd") }

    existing = spaces.map { |space| space.merge("running_pane" => "keep me") }
    existing << {"label" => "Extra", "running_pane" => "keep me too"}
    File.write(File.join(@home, "workspaces.json"), JSON.generate(existing))
    _stdout, stderr, status = run_launcher
    assert status.success?, stderr
    assert_equal existing, spaces
  end

  def test_missing_directory_fails_before_starting_herdr
    FileUtils.remove_entry(File.join(@home, "Documents/Code.nosync/personal/gtd"))
    _stdout, stderr, status = run_launcher
    refute status.success?
    assert_includes stderr, "missing directory"
    refute File.exist?(File.join(@home, "calls.jsonl"))
  end

  def test_ambiguous_spaces_fail_without_creating_more
    File.write(File.join(@home, "ready"), "ready")
    existing = [{"label" => "GTD"}, {"label" => "GTD"}]
    File.write(File.join(@home, "workspaces.json"), JSON.generate(existing))
    _stdout, stderr, status = run_launcher
    refute status.success?
    assert_includes stderr, "ambiguous space: GTD"
    assert_equal existing, spaces
  end

  def test_unexpected_arguments_are_rejected
    _stdout, stderr, status = run_launcher("--session", "default")
    refute status.success?
    assert_includes stderr, "Usage:"
    refute File.exist?(File.join(@home, "calls.jsonl"))
  end
end
