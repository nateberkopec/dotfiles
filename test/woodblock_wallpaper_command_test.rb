# standard:disable Dotfiles/BanFileSystemClasses -- black-box script test requires real temporary files
require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class WoodblockWallpaperCommandTest < Minitest::Test
  def test_prints_command_for_a_wallpaper_from_a_whitelisted_museum
    photos = [
      {id: "rejected", user: {username: "moonshadowpress"}},
      {id: "accepted", user: {username: "thewalters"}}
    ]

    run_command(photos) do |result, curl_trace|
      stdout, stderr, status = result

      assert status.success?, stderr
      assert_equal "splash --plain --id accepted --no-cache\n", stdout
      assert_search_arguments File.readlines(curl_trace, chomp: true)
    end
  end

  def test_skips_recently_used_wallpapers
    photos = [
      {id: "recent", user: {username: "thewalters"}},
      {id: "fresh", user: {username: "artchicago"}}
    ]

    run_command(photos, history: ["recent"]) do |result, _curl_trace|
      stdout, stderr, status = result

      assert status.success?, stderr
      assert_equal "splash --plain --id fresh --no-cache\n", stdout
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

  def run_command(photos, history: [])
    Dir.mktmpdir do |home|
      bin = File.join(home, "bin")
      FileUtils.mkdir_p(bin)
      fixture = File.join(home, "photos.json")
      File.write(fixture, JSON.generate({total_pages: 1, results: photos}))
      FileUtils.mkdir_p(File.join(home, "state/woodblock-wallpaper"))
      File.write(File.join(home, "state/woodblock-wallpaper/history"), history.map { "#{it}\n" }.join)
      curl_trace = File.join(home, "curl.trace")
      write_command(bin, "curl", <<~SH)
        printf '%s\n' "$@" > "$CURL_TRACE"
        cat "$FIXTURE"
      SH

      env = {
        "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
        "UNSPLASH_CLIENT_ID" => "client",
        "XDG_STATE_HOME" => File.join(home, "state"),
        "FIXTURE" => fixture,
        "CURL_TRACE" => curl_trace
      }
      yield Open3.capture3(env, command_source), curl_trace
    end
  end

  def write_command(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\n#{body}")
    FileUtils.chmod(0o755, path)
  end

  def assert_search_arguments(arguments)
    assert_includes ["query=woodblock print", "query=japanese print"], arguments[7]
    assert_equal [
      "--fail", "--silent", "--show-error", "--get",
      "--data-urlencode", "client_id=client",
      "--data-urlencode",
      "--data-urlencode", "orientation=landscape",
      "--data-urlencode", "per_page=30",
      "--data-urlencode", "page=1",
      "https://api.unsplash.com/search/photos"
    ], arguments.values_at(0..6, 8..)
  end

  def command_source
    File.expand_path("../files/home/.local/bin/woodblock-wallpaper-command", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
