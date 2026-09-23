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

  def test_caffeinate_lifecycle_and_release_with_unrelated_assertion
    skip "caffeinate lifecycle test requires macOS" unless macos?
    skip "caffeinate command is not available" unless command?("caffeinate")

    unrelated_pid = Process.spawn("caffeinate", "-i", "-t", "30", out: File::NULL, err: File::NULL)
    output, status = Open3.capture2e("node", "--input-type=module", "-e", harness)

    assert status.success?, output
    assert_match(/caffeinate lifecycle ok/, output)
  ensure
    terminate(unrelated_pid)
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

  def terminate(pid)
    return unless pid

    Process.kill("TERM", pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
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
      // Only this harness's children belong to the extension under test. Other Pi
      // sessions may legitimately hold their own caffeinate assertions.
      const assertions = () => {
        let out = "";
        try {
          out = execFileSync("ps", ["-eo", "pid=,ppid=,args="], { encoding: "utf-8" });
        } catch { return []; }
        return out.split("\\n").map((line) => line.trim()).filter(Boolean)
          .filter((line) => {
            const [, parentPid, ...args] = line.split(/\\s+/);
            return parentPid === String(process.pid) && args.join(" ").startsWith("caffeinate -i");
          });
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
