require "fileutils"
require "open3"

class Dotfiles
  class SystemAdapter
    def file_exist?(path)
      File.exist?(path)
    end

    def dir_exist?(path)
      Dir.exist?(path)
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

    def glob(pattern)
      Dir.glob(pattern)
    end

    def chdir(path, &block)
      Dir.chdir(path, &block)
    end

    def readlines(path)
      File.readlines(path)
    end

    def execute(command, quiet: true)
      if quiet
        output = `#{command} 2>&1`.strip
        [output, $?.exitstatus]
      else
        output = `#{command}`.strip
        status = $?.exitstatus
        [output, status]
      end
    end

    def execute!(command, quiet: true)
      output, status = execute(command, quiet: quiet)
      raise "Command failed: #{command}\nOutput: #{output}" unless status == 0
      [output, status]
    end

    def path_join(*parts)
      File.join(*parts)
    end

    def path_dirname(path)
      File.dirname(path)
    end
  end
end
