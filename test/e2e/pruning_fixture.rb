require "fileutils"
require "securerandom"

class PruningFixture
  CONTENTS = {"launch.sh" => "#!/bin/sh\nexec /bin/sleep 3600\n", "edited.txt" => "owned content", "retired.txt" => "retired content"}.freeze

  attr_reader :id, :relative, :source, :target, :plist, :plist_relative, :service, :original_plist

  def initialize
    raise "Pruning lifecycle requires a macOS E2E runner" unless ENV["GITHUB_ACTIONS"] == "true" && RUBY_PLATFORM.include?("darwin")
    @id = "pruning-e2e-#{SecureRandom.hex(4)}"
    @relative = ".local/share/dotfiles/#{@id}"
    @source = File.join(E2E.dotfiles_dir, "files/home", @relative)
    @target = File.join(E2E.home, @relative)
    @plist_relative = "Library/LaunchAgents/dev.mise.#{@id}.plist"
    @plist = File.join(E2E.home, @plist_relative)
    @service = "gui/#{Process.uid}/dev.mise.#{@id}"
    @manifest = File.join(E2E.dotfiles_dir, "config/pruning.yml")
    @original_manifest = File.binread(@manifest)
  end

  def install
    [@source, @target, @plist].each do |path|
      raise "E2E fixture path already exists: #{path}" if File.exist?(path) || File.symlink?(path)
    end
    @installed = true
    FileUtils.mkdir_p(@source)
    CONTENTS.each { |name, contents| File.write(File.join(@source, name), contents) }
    File.chmod(0o755, File.join(@source, "launch.sh"))
    config = YAML.safe_load(@original_manifest)
    config.fetch("items")[@id] = {"source" => "files/home/#{@relative}", "target" => @relative,
                                 "hook" => {"type" => "launch_agent", "label" => "dev.mise.#{@id}"}}
    File.write(@manifest, YAML.dump(config))
    FileUtils.mkdir_p(File.dirname(@plist))
    agent = {"Label" => "dev.mise.#{@id}", "ProgramArguments" => [File.join(@target, "launch.sh")], "RunAtLoad" => true}
    command!("/usr/bin/plutil", "-convert", "xml1", "-o", @plist, "-", stdin_data: JSON.dump(agent))
    @original_plist = File.binread(@plist)
  end

  def command!(*command, **options)
    output, status = Open3.capture2e(*command, **options)
    raise "#{command.join(" ")} failed: #{output}" unless status.success?
    output
  end

  def converge_user_files(name)
    output, status = Open3.capture2e({"CI" => "true"}, File.join(E2E.dotfiles_dir, "bin/dotf"), "run",
      chdir: E2E.dotfiles_dir, stdin_data: "")
    File.write(File.join(E2E.log_dir, "pruning-#{name}.log"), output)
    [output, status]
  end

  def ledger
    state = ENV.fetch("XDG_STATE_HOME", File.join(E2E.home, ".local/state"))
    JSON.parse(File.read(File.join(state, "dotfiles/deployed.json"))).fetch("items")
  end

  def retire_sources
    FileUtils.rm_rf(@source)
    File.binwrite(@manifest, @original_manifest)
  end

  def close
    return unless @installed
    Open3.capture2e("/bin/launchctl", "bootout", @service)
    retire_sources
    FileUtils.rm_rf(@target)
    FileUtils.rm_f(@plist)
  end
end
