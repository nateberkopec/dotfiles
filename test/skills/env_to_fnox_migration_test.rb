# standard:disable Dotfiles/BanFileSystemClasses -- black-box script tests require real temporary files
require_relative "../test_helper"
require "open3"
require "tmpdir"

class EnvToFnoxMigrationTest < Minitest::Test
  SCRIPT = File.expand_path("../../files/home/.claude/skills/env-to-fnox/scripts/migrate_env_to_fnox.rb", __dir__)

  def test_secret_uses_only_op_stdin_and_config_contains_references
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, ".env")
      File.write(env_file, "API_KEY=super-secret\nEMPTY=''\n")
      make_fake_op(dir)
      output = File.join(dir, "fnox.toml")

      stdout, stderr, status = Open3.capture3(
        {"PATH" => "#{dir}:#{ENV.fetch("PATH")}", "CAPTURE" => dir},
        SCRIPT, "--env-file", env_file, "--vault", "Test", "--item-title", "App", "--output", output
      )

      assert status.success?, stderr
      secret = "super-secret"
      refute_includes stdout + stderr + File.read(output) + File.read(File.join(dir, "argv")), secret
      assert_includes File.read(File.join(dir, "stdin")), secret
      assert_includes File.read(output), "op://Test/App/API_KEY"
      assert File.exist?(env_file)
    end
  end

  def test_verify_uses_generated_config
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, ".env")
      output = File.join(dir, "custom.toml")
      File.write(env_file, "API_KEY=secret\n")
      make_fake_op(dir)
      make_fake_fnox(dir)

      _stdout, stderr, status = Open3.capture3(
        {"PATH" => "#{dir}:#{ENV.fetch("PATH")}", "CAPTURE" => dir},
        SCRIPT, "--env-file", env_file, "--item-title", "App", "--output", output, "--verify"
      )

      assert status.success?, stderr
      assert_includes File.read(File.join(dir, "fnox-argv")), "--config\n#{output}\nget\nAPI_KEY"
    end
  end

  def test_rejects_unsupported_syntax_before_calling_op
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, ".env")
      File.write(env_file, "export API_KEY=secret\n")
      make_fake_op(dir)

      _stdout, stderr, status = Open3.capture3(
        {"PATH" => "#{dir}:#{ENV.fetch("PATH")}", "CAPTURE" => dir},
        SCRIPT, "--env-file", env_file, "--item-title", "App"
      )

      refute status.success?
      assert_includes stderr, "line 1"
      refute File.exist?(File.join(dir, "stdin"))
    end
  end

  private

  def make_fake_fnox(dir)
    path = File.join(dir, "fnox")
    File.write(path, <<~RUBY)
      #!/usr/bin/env ruby
      File.write(File.join(ENV.fetch("CAPTURE"), "fnox-argv"), ARGV.join("\\n"))
    RUBY
    File.chmod(0o755, path)
  end

  def make_fake_op(dir)
    path = File.join(dir, "op")
    File.write(path, <<~'RUBY')
      #!/usr/bin/env ruby
      File.write(File.join(ENV.fetch("CAPTURE"), "argv"), ARGV.join("\n"))
      File.write(File.join(ENV.fetch("CAPTURE"), "stdin"), $stdin.read)
    RUBY
    File.chmod(0o755, path)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
