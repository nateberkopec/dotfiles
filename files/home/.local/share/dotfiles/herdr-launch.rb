require "fileutils"
require "json"
require "open3"

class PersonalHerdr
  def initialize
    @environment = ENV.keys.grep(/^HERDR_/).to_h { |key| [key, nil] }.merge(
      "XDG_CONFIG_HOME" => File.expand_path("~/.config/herdr-personal"),
      "XDG_STATE_HOME" => File.expand_path("~/.local/state/herdr-personal")
    )
    @pane_environment = {
      "XDG_CONFIG_HOME" => ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
      "XDG_STATE_HOME" => ENV.fetch("XDG_STATE_HOME", File.expand_path("~/.local/state"))
    }.flat_map { |key, value| ["--env", "#{key}=#{value}"] }
    config = File.join(@environment.fetch("XDG_CONFIG_HOME"), "herdr/spaces.json")
    @spaces = JSON.parse(File.read(config)).fetch("spaces")
    @spaces.each do |space|
      space["cwd"] = File.expand_path(space.fetch("cwd"))
      raise ArgumentError, "missing directory: #{space["cwd"]}" unless File.directory?(space["cwd"])
      raise ArgumentError, "empty space label" if space.fetch("label").empty?
    end
    labels = @spaces.map { |space| space.fetch("label") }
    raise ArgumentError, "duplicate space labels" unless labels.uniq == labels
  end

  def call(*arguments)
    output, error, status = Open3.capture3(@environment, "herdr", "--session", "default", *arguments)
    raise error.strip unless status.success?
    JSON.parse(output).fetch("result")
  end

  def wait_for_server
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    loop do
      return call("workspace", "list").fetch("workspaces")
    rescue RuntimeError
      raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.2
    end
  end

  def workspaces
    call("workspace", "list").fetch("workspaces")
  rescue RuntimeError
    pid = Process.spawn(@environment, "herdr", "--session", "default", "server", in: File::NULL, out: File::NULL, err: File::NULL, pgroup: true)
    Process.detach(pid)
    wait_for_server
  end

  def launch
    directory = File.join(@environment.fetch("XDG_STATE_HOME"), "herdr")
    FileUtils.mkdir_p(directory)
    File.open(File.join(directory, "spaces.lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      existing = workspaces
      @spaces.each do |space|
        matches = existing.select { |workspace| workspace.fetch("label") == space.fetch("label") }
        raise "ambiguous space: #{space["label"]}" if matches.length > 1
        next unless matches.empty?
        call("workspace", "create", "--label", space.fetch("label"), "--cwd", space.fetch("cwd"), "--no-focus", *@pane_environment)
      end
    end
    exec @environment, "herdr", "--session", "default"
  end
end

begin
  abort "Usage: herdr-launch.rb" unless ARGV.empty?
  PersonalHerdr.new.launch
rescue => error
  warn "herdr: #{error.message}"
  exit 1
end
