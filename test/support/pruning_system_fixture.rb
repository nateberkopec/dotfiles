require "json"
require "open3"
require "yaml"

module PruningSystemFixture
  def setup
    @system = Dotfiles::SystemAdapter.new
    template = File.join(ENV.fetch("TMPDIR", "/tmp"), "dotfiles-pruning.XXXXXXXX")
    @temporary = @system.execute!(["mktemp", "-d", template]).first
    @root = File.join(@temporary, "repo")
    @home = File.join(@temporary, "home")
    @state = File.join(@temporary, "state")
    @system.mkdir_p([File.join(@root, "files/home"), File.join(@root, "config"), @home])
    @source = "files/home/.pi/agent/extensions"
    @target = ".pi/agent/extensions"
    @items = {"extensions" => {"source" => @source, "target" => @target}}
    configure
    deploy("example.ts", "original")
  end

  def teardown
    @system.rm_rf(@temporary)
  end

  private

  def configure
    write(File.join(@root, "config/pruning.yml"), YAML.dump({"version" => 1, "items" => @items}))
  end

  def deploy(name, contents)
    write(File.join(@root, @source, name), contents)
    write(File.join(@home, @target, name), contents)
  end

  def write(path, contents)
    @system.mkdir_p(File.dirname(path))
    @system.write_file(path, contents)
  end

  def run_pruning
    env = {"HOME" => @home, "DOTFILES_DIR" => @root, "XDG_STATE_HOME" => @state,
           "PATH" => "#{@temporary}/bin:#{ENV.fetch("PATH")}"}
    script = File.expand_path("../../bin/lib/prune-managed-files.rb", __dir__)
    Open3.capture2e(env, RbConfig.ruby, script)
  end

  def successful_run
    output, status = run_pruning
    assert status.success?, output
    output
  end

  def ledger_path
    File.join(@state, "dotfiles/deployed.json")
  end

  def ledger
    JSON.parse(@system.read_file(ledger_path))
  end
end
