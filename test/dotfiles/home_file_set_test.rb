require "test_helper"

class HomeFileSetTest < Minitest::Test
  def test_entries_default
    assert_empty file_set.entries
  end

  def test_entries_prefer_host_over_platform_and_shared_files
    @fake_system.stub_macos
    @fake_system.stub_hostname("workspaces")
    stub_source_file(".config/app/config", "shared")
    stub_source_file(".config/app/config", "mac", root: "home.macos")
    stub_source_file(".config/app/config", "host", root: "home.hosts/workspaces")

    assert_equal [source_path(".config/app/config", root: "home.hosts/workspaces")], entry_sources
  end

  def test_entries_ignore_local_state_files
    stub_source_file(".config/fish/fish_variables", "local")
    stub_source_file(".pi/agent/auth.json", "secret")

    assert_empty file_set.entries
  end

  private

  def file_set
    Dotfiles::HomeFileSet.new(dotfiles_dir: @dotfiles_dir, home: @home, system: @fake_system)
  end

  def entry_sources
    file_set.entries.map { |entry| entry[:src] }
  end

  def source_path(relative, root: "home")
    File.join(@dotfiles_dir, "files", root, relative)
  end

  def stub_source_file(relative, content, root: "home")
    path = source_path(relative, root: root)
    @fake_system.mkdir_p(File.dirname(path))
    @fake_system.stub_file_content(path, content)
  end
end
