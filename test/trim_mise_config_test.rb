require "test_helper"
require "toml-rb"

# standard:disable Dotfiles/BanFileSystemClasses
class TrimMiseConfigTest < Minitest::Test
  def test_trims_ci_managed_tables_and_removes_launchd
    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.toml")
      File.write(path, <<~TOML)
        [tools]
        ruby = "4.0.6"
        node = "26.5.0"
        gh = "2.96.0"
        "npm:@earendil-works/pi-coding-agent" = { version = "0.83.0", aube_args = "--deny-build=@google/genai --deny-build=protobufjs" }

        [bootstrap.packages]
        "brew:git" = "latest"
        "apt:curl" = "latest"

        [bootstrap.macos.launchd.agents.yknotify]
        program = "yknotify"

        [bootstrap.macos.launchd.agents.woodblock-wallpaper]
        program = "wallpaper"

        [bootstrap.macos.launchd.agents.omniwm]
        program = "omniwm"

        [settings]
        experimental = true
      TOML
      env = {
        "MISE_CI_TOOLS" => "ruby,gh,npm:@earendil-works/pi-coding-agent",
        "BREW_CI_PACKAGES" => "ba\"sh",
        "DEBIAN_CI_PACKAGES" => "curl"
      }
      assert system(env, RbConfig.ruby, script_path, path)

      rendered = File.read(path)
      TomlRB.parse(rendered)
      assert_includes rendered, 'ruby = "4.0.6"'
      assert_includes rendered, 'gh = "2.96.0"'
      assert_includes rendered, "--deny-build=@google/genai --deny-build=protobufjs"
      assert_includes rendered, "\"brew:ba\\\"sh\" = \"latest\""
      assert_includes rendered, "\"apt:curl\" = \"latest\""
      assert_includes rendered, "experimental = true"
      refute_includes rendered, "node ="
      refute_includes rendered, "launchd"
    end
  end

  private

  def script_path
    File.expand_path("../tools/ci/trim_mise_config.rb", __dir__)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
