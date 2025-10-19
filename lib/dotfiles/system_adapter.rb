require "digest"
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

    def file_hash(path)
      File.open(path, "rb") do |file|
        Digest::SHA256.hexdigest(file.read)
      end
    end

    def execute(command, quiet: true, capture_output: false, check_status: false, return_status: false)
      if return_status
        output = `#{command} 2>&1`
        [output, $?.exitstatus]
      elsif check_status
        system(command)
      elsif quiet || capture_output
        stdout, stderr, status = Open3.capture3(command)
        raise "Command failed: #{command}\n#{stderr}" unless status.success?
        stdout
      else
        system(command) || raise("Command failed: #{command}")
      end
    end
  end
end
