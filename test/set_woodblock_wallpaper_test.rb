# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class SetWoodblockWallpaperTest < Minitest::Test
  def test_sets_first_wallpaper_from_a_whitelisted_museum
    photos = [
      {id: "rejected", user: {username: "moonshadowpress"}},
      {id: "accepted", user: {username: "thewalters"}},
      {id: "also-accepted", user: {username: "artchicago"}}
    ]

    run_wallpaper(photos, "--user", "moonshadowpress") do |result, traces|
      _stdout, stderr, status = result

      assert status.success?, stderr
      assert_equal %w[--plain --id accepted --no-cache], File.readlines(traces.fetch(:splash), chomp: true)
      assert_equal expected_curl_arguments, File.readlines(traces.fetch(:curl), chomp: true)
    end
  end

  def test_rejects_results_without_a_whitelisted_museum
    run_wallpaper([{id: "rejected", user: {username: "moonshadowpress"}}]) do |result, traces|
      _stdout, stderr, status = result

      refute status.success?
      assert_includes stderr, "No woodblock prints found from whitelisted museum accounts"
      refute File.exist?(traces.fetch(:splash))
    end
  end

  private

  def run_wallpaper(photos, *arguments)
    skip "fish is required for wallpaper tests" unless system("fish", "--version", out: File::NULL, err: File::NULL)

    Dir.mktmpdir do |home|
      bin = File.join(home, ".local/bin")
      FileUtils.mkdir_p(bin)
      fixture = File.join(home, "photos.json")
      File.write(fixture, JSON.generate(photos))
      traces = {curl: File.join(home, "curl.trace"), splash: File.join(home, "splash.trace")}
      write_command(bin, "curl", <<~SH)
        printf '%s\n' "$@" > "$CURL_TRACE"
        cat "$FIXTURE"
      SH
      write_command(bin, "splash", <<~SH)
        printf '%s\n' "$@" > "$SPLASH_TRACE"
      SH

      env = {
        "HOME" => home,
        "UNSPLASH_CLIENT_ID" => "client",
        "UNSPLASH_CLIENT_SECRET" => "secret",
        "FIXTURE" => fixture,
        "CURL_TRACE" => traces.fetch(:curl),
        "SPLASH_TRACE" => traces.fetch(:splash)
      }
      yield Open3.capture3(env, wallpaper_source, *arguments), traces
    end
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\n#{body}")
    FileUtils.chmod(0o755, path)
  end

  def expected_curl_arguments
    [
      "--fail", "--silent", "--show-error", "--get",
      "--data-urlencode", "client_id=client",
      "--data-urlencode", "query=woodblock print",
      "--data-urlencode", "orientation=landscape",
      "--data-urlencode", "count=30",
      "https://api.unsplash.com/photos/random"
    ]
  end

  def wallpaper_source
    File.expand_path("../files/home/.local/bin/set-woodblock-wallpaper", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
