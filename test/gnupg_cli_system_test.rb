require "test_helper"
require "tmpdir"
require "toml-rb"

class GnupgCliSystemTest < Minitest::Test
  def test_deploys_the_package_managed_gpg_only_on_macos
    config = TomlRB.load_file(File.expand_path("../files/home/.config/mise/config.toml", __dir__))
    entry = config.fetch("dotfiles").fetch("~/.local/bin/gpg")
    assert_equal "/opt/homebrew/bin/gpg", entry.fetch("source")
    assert_equal "latest", config.dig("bootstrap", "packages", "brew:gnupg")
    mise = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |path| File.join(path, "mise") }.find { |path| File.executable?(path) }

    Dir.mktmpdir("gnupg-cli") do |directory|
      package_bin = File.join(directory, "package/bin/gpg")
      FileUtils.mkdir_p(File.dirname(package_bin))
      File.write(package_bin, "#!/bin/sh\nprintf '%s\\n' 'package-managed gpg'\n")
      File.chmod(0o755, package_bin)
      config_path = File.join(directory, "config.toml")
      File.write(config_path, TomlRB.dump({"dotfiles" => {"~/.local/bin/gpg" => entry.merge("source" => package_bin)}}))
      env = {"HOME" => directory, "PATH" => "/usr/bin:/bin", "MISE_GLOBAL_CONFIG_FILE" => config_path,
             "MISE_CONFIG_DIR" => File.join(directory, "config"), "MISE_DATA_DIR" => File.join(directory, "data"),
             "MISE_STATE_DIR" => File.join(directory, "state"), "MISE_CACHE_DIR" => File.join(directory, "cache"),
             "MISE_TRUSTED_CONFIG_PATHS" => directory, "BASH_ENV" => ""}
      2.times do
        output, status = Open3.capture2e(env, mise, "dotfiles", "apply", chdir: directory, unsetenv_others: true)
        assert status.success?, output
      end
      link = File.join(directory, ".local/bin/gpg")
      if RUBY_PLATFORM.include?("darwin")
        assert_equal package_bin, File.readlink(link)
        output, status = Open3.capture2e(env.merge("PATH" => "#{directory}/.local/bin:/usr/bin:/bin"),
          "/bin/bash", "-c", "command -v gpg && gpg --version", chdir: directory, unsetenv_others: true)
        assert status.success?, output
        assert_equal "#{link}\npackage-managed gpg\n", output
      else
        refute File.exist?(link)
        refute File.symlink?(link)
      end
    end
  end
end
