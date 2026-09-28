# standard:disable Dotfiles/BanFileSystemClasses -- installer source assertions
require "test_helper"
require "open3"

class MeridianPiScrubInstallTest < Minitest::Test
  INSTALLER = File.expand_path("../bin/lib/install-meridian-pi-scrub.rb", __dir__)
  HOOK = File.expand_path("../bin/lib/post-dotfiles-hook.sh", __dir__)

  def test_bootstrap_hook_installs_pinned_plugin
    assert_includes File.read(HOOK), "ruby \"$HOME/.dotfiles/bin/lib/install-meridian-pi-scrub.rb\""
    source = File.read(INSTALLER)
    assert_includes source, "meridian-plugin-pi-scrub-v"
    assert_includes source, "Digest::SHA256.file(archive).hexdigest == SHA256"
    assert_includes source, '".config/meridian/plugins.json"'
    output, status = Open3.capture2e("ruby", "-c", INSTALLER)
    assert status.success?, output
  end
end
# standard:enable Dotfiles/BanFileSystemClasses
