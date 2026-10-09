require "json"
require "minitest/autorun"
require "open3"
require "yaml"

module E2E
  ALLOWED_FAILURES = ["Update macOS", "Configure Downloads Inbox Folder Action"].freeze
  ANSI = /\e\[[0-9;?]*[A-Za-z]/

  module_function

  def home
    Dir.home
  end

  def dotfiles_dir
    File.join(home, ".dotfiles")
  end

  def log_dir
    ENV.fetch("DOTF_E2E_LOG_DIR")
  end

  def run_log(name)
    File.read(File.join(log_dir, "#{name}.log"), encoding: "UTF-8").gsub(ANSI, "")
  end

  def fish(command)
    Open3.capture3("fish", "-l", "-c", command)
  end

  def fish!(command)
    stdout, stderr, status = fish(command)
    raise "fish -l -c #{command.inspect} exited #{status.exitstatus}: #{stderr}" unless status.success?
    stdout
  end

  def admin?
    fish!("id -Gn").split.include?("admin")
  end

  def config
    YAML.safe_load_file(File.join(dotfiles_dir, "config", "config.yml"))
  end
end
