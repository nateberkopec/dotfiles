require "fileutils"
require "open3"

class Dotfiles
  class SystemAdapter
    def macos?
      RUBY_PLATFORM.include?("darwin")
    end

    def linux?
      RUBY_PLATFORM.include?("linux")
    end

    def debian?
      linux? && File.exist?("/etc/debian_version")
    end

    def running_codespaces?
      ENV["CODESPACES"] == "true"
    end

    def running_container?
      File.exist?("/.dockerenv") ||
        (File.exist?("/proc/1/cgroup") && File.read("/proc/1/cgroup").include?("docker"))
    end

    def file_exist?(path)
      File.exist?(path)
    end

    def dir_exist?(path)
      Dir.exist?(path)
    end

    def symlink?(path)
      File.symlink?(path)
    end

    def readlink(path)
      File.readlink(path)
    end

    def create_symlink(target, link_path)
      File.symlink(target, link_path)
    end

    def read_file(path)
      File.read(path)
    end

    def write_file(path, content)
      File.write(path, content)
    end

    def mkdir_p(path)
      FileUtils.mkdir_p(path)
    end

    def cp(src, dest)
      FileUtils.cp(src, dest)
    end

    def cp_r(src, dest)
      FileUtils.cp_r(src, dest)
    end

    def rm_rf(path)
      FileUtils.rm_rf(path)
    end

    def chmod(mode, path)
      File.chmod(mode, path)
    end

    def glob(pattern, flags = 0)
      Dir.glob(pattern, flags)
    end

    def chdir(path, &block)
      Dir.chdir(path, &block)
    end

    def readlines(path)
      File.readlines(path)
    end

    def execute(command, quiet: true)
      quiet ? execute_quiet(command) : execute_verbose(command)
    rescue Errno::ENOENT => e
      [e.message, 127]
    end

    def execute_quiet(command)
      stdout_and_stderr, status = Open3.capture2e(*open3_command(command))
      [stdout_and_stderr.strip, status.exitstatus]
    end

    def execute_verbose(command)
      output = +""
      status = stream_output(command, output)
      [output.strip, status]
    end

    def stream_output(command, output)
      Open3.popen2e(*open3_command(command)) do |_stdin, stdout_and_stderr, wait_thread|
        stdout_and_stderr.each do |line|
          print line
          output << line
        end
        return wait_thread.value.exitstatus
      end
    end

    def execute!(command, quiet: true)
      output, status = execute(command, quiet: quiet)
      raise "Command failed: #{command}\nOutput: #{output}" unless status == 0
      [output, status]
    end

    private

    def open3_command(command)
      command.is_a?(Array) ? command : [command]
    end
  end
end
