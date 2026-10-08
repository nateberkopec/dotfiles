# standard:disable Dotfiles/BanFileSystemClasses -- isolated Pi state for extension contract tests
require "open3"
require "tmpdir"

module MeridianExtensionHelper
  EXTENSION = File.expand_path("../../files/home/.pi/agent/extensions/meridian.ts", __dir__)
  HELPERS = File.expand_path("../../files/home/.pi/agent/extensions/meridian", __dir__)

  def run_wrapper(source, env = {}, query = "meridian")
    Dir.mktmpdir("meridian-provider") do |agent_dir|
      wrapper = File.join(agent_dir, "verify_meridian.ts")
      File.write(wrapper, source)
      run_extension({"PI_OFFLINE" => nil}.merge(env).merge("PI_CODING_AGENT_DIR" => agent_dir), wrapper, query)
    end
  end

  def verify_contract(source)
    output, status = run_wrapper(<<~TS, {"PI_OFFLINE" => "1"})
      import assert from "node:assert/strict";
      #{source}
      export default async function verify() { await check(); }
    TS
    assert status.success?, output
    refute_match(/Failed to load extension|Extension error/, output)
  end

  def run_extension(env, extension = EXTENSION, query = "claude-opus-4-6")
    Open3.capture2e(env, "pi", "--no-extensions", "--extension", extension, "--list-models", query)
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
