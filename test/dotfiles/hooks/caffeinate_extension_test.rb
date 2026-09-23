require "test_helper"
require "open3"

# standard:disable Dotfiles/BanFileSystemClasses -- black-box test shells out to node/ps
class CaffeinateExtensionTest < Minitest::Test
  EXTENSION = File.expand_path("../../../files/home/.pi/agent/extensions/caffeinate.ts", __dir__)
  UPSTREAM_SHA = "3a7629bd3bb119cea6f428e1fca751c4f7089934"
  UPSTREAM_HEADER = %r{Vendored from https://github\.com/forlorn-echo/pi-caffeinate at\n// #{UPSTREAM_SHA}}

  def test_vendored_source_matches_upstream_behavior
    vendored = read_extension
    header, body = split_header(vendored)
    assert_match(UPSTREAM_HEADER, header)
    assert_includes body, 'if (process.platform !== "darwin") return;'
    assert_includes body, 'spawn(CAFFEINATE_COMMAND, ["-i", "-t", String(ASSERTION_TIMEOUT_SECONDS)]'
    assert_includes body, 'pi.on("agent_start"'
    assert_includes body, 'pi.on("agent_settled"'
    assert_includes body, 'pi.on("session_shutdown"'
    assert_includes body, "refreshTimer.unref?.();"
  end

  def test_caffeinate_lifecycle_and_release
    skip "caffeinate lifecycle test requires macOS" unless macos?
    skip "caffeinate command is not available" unless command?("caffeinate")
    flunk "leftover caffeinate -i assertions before test:\n#{idle_assertions.join("\n")}" unless idle_assertions.empty?

    output, status = Open3.capture2e("node", "--input-type=module", "-e", harness)
    assert status.success?, output
    assert_match(/caffeinate lifecycle ok/, output)
  ensure
    flunk "caffeinate -i assertion leaked after test:\n#{idle_assertions.join("\n")}" if macos? && !idle_assertions.empty?
  end

  private

  def read_extension
    Dotfiles::SystemAdapter.new.read_file(EXTENSION)
  end

  def split_header(content)
    lines = content.lines
    header = lines.take_while { |line| line.start_with?("//") }.join
    [header, lines.drop_while { |line| line.start_with?("//") }.join]
  end

  def macos?
    RUBY_PLATFORM.include?("darwin")
  end

  def command?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      path = File.join(directory, name)
      File.executable?(path) && !File.directory?(path)
    end
  end

  # ps-based (not pgrep): avoids pgrep self-match and full-command subtleties.
  # Our own ruby cmdline never contains the literal "caffeinate -i".
  def idle_assertions
    output, status = Open3.capture2("ps", "-eo", "pid,args")
    return [] unless status.success?

    output.lines.map(&:strip).reject(&:empty?)
      .select { |line| line.include?("caffeinate -i") }
  end

  def harness
    <<~JS
      import caffeinate from #{EXTENSION.inspect};

      const handlers = {};
      const fakePi = { on: (event, handler) => { (handlers[event] ??= []).push(handler); } };
      const ctx = { hasUI: false, ui: { notify: () => {} } };

      caffeinate(fakePi);
      for (const event of ["agent_start", "agent_settled", "session_shutdown"]) {
        if (!handlers[event]?.length) throw new Error(`missing ${event} handler`);
      }

      const { execFileSync, spawnSync } = await import("node:child_process");
      // ps-based listing; exclude our own node process (its -e script contains the literal).
      const assertions = () => {
        let out = "";
        try {
          out = execFileSync("ps", ["-eo", "pid,args"], { encoding: "utf-8" });
        } catch { return []; }
        const self = String(process.pid);
        return out.split("\\n").map((line) => line.trim()).filter(Boolean)
          .filter((line) => line.includes("caffeinate -i") && !line.startsWith(self + " "));
      };
      const waitFor = (want, label) => {
        const deadline = Date.now() + 5000;
        for (;;) {
          const found = assertions();
          if (want ? found.length : !found.length) return found;
          if (Date.now() > deadline) throw new Error(`${label}: still [${found.join(" | ")}]`);
          spawnSync("sleep", ["0.2"]);
        }
      };

      handlers.agent_start[0]({}, ctx);
      const spawned = waitFor(true, "caffeinate -i was not spawned on agent_start");
      const pid = spawned[0].split(/\\s+/, 1)[0];
      const args = execFileSync("ps", ["-o", "args=", "-p", pid], { encoding: "utf-8" });
      if (!args.includes("-t 300")) throw new Error("spawned assertion missing bounded timeout");

      handlers.agent_settled[0]();
      waitFor(false, "assertion leaked after agent_settled");

      handlers.agent_start[0]({}, ctx);
      waitFor(true, "caffeinate -i was not re-spawned on second agent_start");
      handlers.session_shutdown[0]();
      waitFor(false, "assertion leaked after session_shutdown");

      console.log("caffeinate lifecycle ok");
      process.exit(0);
    JS
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
