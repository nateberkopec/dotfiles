# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class WoodblockWallpaperCommandTest < Minitest::Test
  def test_prints_command_for_first_wallpaper_from_a_whitelisted_museum
    photos = [
      {id: "rejected", user: {username: "moonshadowpress"}},
      {id: "accepted", user: {username: "thewalters"}},
      {id: "also-accepted", user: {username: "artchicago"}}
    ]

    run_command(photos, "--user", "moonshadowpress") do |result, curl_trace|
      stdout, stderr, status = result

      assert status.success?, stderr
      assert_equal "splash --plain --id accepted --no-cache\n", stdout
      assert_equal expected_curl_arguments, File.readlines(curl_trace, chomp: true)
    end
  end

  def test_rejects_results_without_a_whitelisted_museum
    run_command([{id: "rejected", user: {username: "moonshadowpress"}}]) do |result, _curl_trace|
      stdout, stderr, status = result

      refute status.success?
      assert_empty stdout
      assert_includes stderr, "No woodblock prints found from whitelisted museum accounts"
    end
  end

  def test_rejects_an_unsafe_photo_id
    run_command([{id: "accepted; touch /tmp/pwned", user: {username: "thewalters"}}]) do |result, _curl_trace|
      stdout, stderr, status = result

      refute status.success?
      assert_empty stdout
      assert_includes stderr, "Unsplash returned an invalid photo ID"
    end
  end

  private

  def run_command(photos, *arguments)
    Dir.mktmpdir do |home|
      bin = File.join(home, "bin")
      FileUtils.mkdir_p(bin)
      fixture = File.join(home, "photos.json")
      File.write(fixture, JSON.generate(photos))
      curl_trace = File.join(home, "curl.trace")
      write_command(bin, "curl", <<~SH)
        printf '%s\n' "$@" > "$CURL_TRACE"
        cat "$FIXTURE"
      SH

      env = {
        "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
        "UNSPLASH_CLIENT_ID" => "client",
        "FIXTURE" => fixture,
        "CURL_TRACE" => curl_trace
      }
      yield Open3.capture3(env, command_source, *arguments), curl_trace
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

  def command_source
    File.expand_path("../files/home/.local/bin/woodblock-wallpaper-command", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
