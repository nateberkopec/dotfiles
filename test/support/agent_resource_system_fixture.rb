require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

module AgentResourceSystemFixture
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @directory = Dir.mktmpdir("agent-resource-system")
    @home = File.join(@directory, "home")
    @root = File.join(@directory, "dotfiles")
    @package = File.join(@home, ".pi/agent/git/github.com/nateberkopec/agent-stuff")
    @config = YAML.safe_load_file(File.join(ROOT, "config/config.yml"))
    FileUtils.mkdir_p([File.join(@root, "config"), File.join(@root, "files/home"), File.join(@home, ".pi/agent")])
    %w[config.yml agent_resource_baselines.json].each do |name|
      FileUtils.cp(File.join(ROOT, "config", name), File.join(@root, "config", name))
    end
    File.write(File.join(@root, "config/pruning.yml"), YAML.dump("version" => 1, "items" => {}))
    settings = JSON.parse(File.read(File.join(ROOT, "files/home/.pi/agent/settings.json")))
    source = settings.fetch("packages").find { |entry| entry.is_a?(Hash) && entry.fetch("source").include?("agent-stuff@") }.fetch("source")
    meridian = settings.fetch("packages").find { |entry| entry.is_a?(String) && entry.start_with?("npm:@nateberkopec/pi-meridian@") }
    assert meridian, "Pinned Meridian package missing"
    File.write(File.join(@home, ".pi/agent/settings.json"), JSON.generate(
      "npmCommand" => ["bash", "-c", 'exec bash "$1" "${@:2}"', "npm", File.join(ROOT, "files/home/.pi/agent/pi-npm.sh")],
      "packages" => [{"source" => source, "skills" => []}, meridian]
    ))
    [source, meridian].each do |package|
      output, status = Open3.capture2e(environment.merge("HOME" => ENV.fetch("HOME")), "pi", "install", package, chdir: ROOT)
      assert status.success?, output
    end
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  private

  def environment
    {"HOME" => @home, "PI_CODING_AGENT_DIR" => File.join(@home, ".pi/agent"),
     "PI_OFFLINE" => "1", "MISE_DATA_DIR" => ENV.fetch("MISE_DATA_DIR", File.join(ENV.fetch("HOME"), ".local/share/mise")),
     "XDG_STATE_HOME" => File.join(@home, ".local/state")}
  end

  def link_resources
    Open3.capture2e(environment, RbConfig.ruby, File.join(ROOT, "bin/lib/link-agent-resources.rb"), @root, @home)
  end

  def seed_legacy
    %w[extensions/notify.ts prompts/plan-follow.md agents/reviewer.md].each do |relative|
      target = File.join(@home, ".pi/agent", relative)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(@package, relative), target)
    end
    FileUtils.mkdir_p(File.join(@home, ".agents"))
    FileUtils.cp(File.join(@package, "agents/researcher.md"), File.join(@home, ".agents/researcher.md"))
    File.symlink(File.join(@root, "removed-skills"), File.join(@home, ".agents/skills"))
    File.write(File.join(@home, ".pi/agent/extensions/custom.ts"), "custom extension")
    baselines = JSON.parse(File.read(File.join(@root, "config/agent_resource_baselines.json")))
    claimed = %w[.pi/agent/agents/reviewer.md .agents/researcher.md .pi/agent/extensions/notify.ts]
    items = {"old-resources" => {"files" => claimed.to_h { |path| [path, {"type" => "file", "sha256" => baselines.fetch(path).last}] }}}
    FileUtils.mkdir_p(File.dirname(ledger_path))
    File.write(ledger_path, JSON.generate("version" => 1, "items" => items))
  end

  def ledger_path
    File.join(@home, ".local/state/dotfiles/deployed.json")
  end
end
