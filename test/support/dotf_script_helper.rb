# standard:disable Dotfiles/BanFileSystemClasses
require "fileutils"
require "shellwords"
require "tmpdir"

module DotfScriptHelper
  def with_dotf_script
    Dir.mktmpdir("dotf-log-rotation") do |tmpdir|
      bin_dir = File.join(tmpdir, "bin")
      logs_dir = File.join(tmpdir, "logs")
      FileUtils.mkdir_p(bin_dir)
      FileUtils.mkdir_p(logs_dir)

      script_path = File.join(bin_dir, "dotf")
      FileUtils.cp(File.expand_path("../../bin/dotf", __dir__), script_path)

      yield tmpdir, script_path, logs_dir
    end
  end

  def seed_dotf_logs(logs_dir)
    31.times do |index|
      File.write(File.join(logs_dir, format("dotf_2000-01-01_00-00-%02d.log", index)), "old")
    end
    File.write(File.join(logs_dir, "other.log"), "keep")
  end

  def write_command_stub(bin_dir, command)
    path = File.join(bin_dir, command)
    File.write(path, <<~BASH)
      #!/bin/bash
      env_prefix=()
      for var in HOMEBREW_AUTO_UPDATE_SECS HOMEBREW_NO_AUTO_UPDATE MISE_EXPERIMENTAL; do
        if [ -n "${!var+x}" ]; then
          env_prefix+=("$var=${!var}")
        fi
      done
      if [ ${#env_prefix[@]} -gt 0 ]; then
        printf '%s ' "${env_prefix[@]}" >> "$DOTF_UPGRADE_LOG"
      fi
      printf '%s %s\n' "#{command}" "$*" >> "$DOTF_UPGRADE_LOG"
    BASH
    FileUtils.chmod("+x", path)
  end

  def source_script_and_init_logging(script_path, log_file_record)
    command = [
      "source #{Shellwords.escape(script_path)}",
      "init_logging",
      "printf '%s\\n' \"$LOG_FILE\" > #{Shellwords.escape(log_file_record)}"
    ].join("; ")

    assert system("bash", "-c", command)
  end

  def current_dotf_logs(logs_dir)
    Dir.children(logs_dir).grep(/\Adotf_.*\.log\z/)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
