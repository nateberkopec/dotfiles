require_relative "e2e_helper"
require_relative "pruning_fixture"

class PruningTest < Minitest::Test
  def setup
    @fixture = PruningFixture.new
    @fixture.install
  end

  def teardown
    @fixture&.close
  end

  def test_real_convergence_preserves_edits_and_retires_the_running_agent
    output, status = @fixture.converge("adopt")
    assert status.success?, output
    owned = @fixture.ledger.fetch(@fixture.id).fetch("files")
    expected = PruningFixture::CONTENTS.keys.map { |name| "#{@fixture.relative}/#{name}" } + [@fixture.plist_relative]
    assert_equal expected.sort, owned.keys.sort
    PruningFixture::CONTENTS.each do |name, contents|
      assert_equal contents, File.read(File.join(@fixture.target, name))
    end
    @fixture.command!("/bin/launchctl", "bootstrap", "gui/#{Process.uid}", @fixture.plist)
    pid = @fixture.command!("/bin/launchctl", "kickstart", "-p", @fixture.service)
    assert_match(/\A\d+\s*\z/, pid)

    preserve_local_changes(owned)
    File.write(File.join(@fixture.target, "edited.txt"), PruningFixture::CONTENTS.fetch("edited.txt"))
    File.binwrite(@fixture.plist, @fixture.original_plist)
    @fixture.retire_sources
    output, status = @fixture.converge("retire")
    assert status.success?, output
    refute @fixture.ledger.key?(@fixture.id)
    refute File.exist?(@fixture.plist)
    PruningFixture::CONTENTS.each_key { |name| refute File.exist?(File.join(@fixture.target, name)), name }
    assert_equal "untracked content", File.read(File.join(@fixture.target, "untracked.txt"))
    output, _stderr, status = Open3.capture3("/bin/launchctl", "print", @fixture.service)
    refute status.success?, output
  end

  private

  def preserve_local_changes(owned)
    ["edited.txt", "retired.txt"].each { |name| File.unlink(File.join(@fixture.source, name)) }
    File.write(File.join(@fixture.target, "edited.txt"), "local changes")
    File.write(File.join(@fixture.target, "untracked.txt"), "untracked content")
    @fixture.command!("/usr/libexec/PlistBuddy", "-c", "Add :E2ELocalEdit bool true", @fixture.plist)
    edited_plist = File.binread(@fixture.plist)
    output, status = @fixture.converge("pending")
    refute status.success?, output
    assert_includes output, "Preserving modified retired files"
    assert_includes output, "edited.txt"
    assert_equal "local changes", File.read(File.join(@fixture.target, "edited.txt"))
    assert_equal "retired content", File.read(File.join(@fixture.target, "retired.txt"))
    assert_equal edited_plist, File.binread(@fixture.plist)
    assert_equal "untracked content", File.read(File.join(@fixture.target, "untracked.txt"))
    assert_equal owned, @fixture.ledger.fetch(@fixture.id).fetch("files")
    @fixture.command!("/bin/launchctl", "print", @fixture.service)
  end
end
