require "test_helper"

class RemoveRetiredCommandLineToolsMigrationTest < Minitest::Test
  include SystemAssertions

  def test_removes_installed_homebrew_formulae_on_macos
    @fake_system.stub_macos
    migration = create_migration
    formulae.each { |formula| stub_brew_formula(formula, installed: true) }

    migration.up

    formulae.each { |formula| assert_executed!(brew_command("uninstall", formula)) }
  end

  def test_preserves_absent_homebrew_formulae
    @fake_system.stub_macos
    migration = create_migration
    formulae.each { |formula| stub_brew_formula(formula, installed: false) }

    migration.up

    formulae.each do |formula|
      refute @fake_system.received_operation?(:execute!, brew_command("uninstall", formula), {quiet: true})
    end
  end

  def test_removes_thefuck_on_debian
    @fake_system.stub_debian
    @fake_system.stub_command(["dpkg-query", "--show", "thefuck"], "thefuck", exit_status: 0)

    create_migration.up

    assert_executed!(["sudo", "apt-get", "remove", "--yes", "thefuck"])
  end

  def test_removes_managed_tool_files
    create_migration.up

    assert @fake_system.received_operation?(:rm_rf, File.join(@home, ".config", "fish", "functions", "fuck.fish"))
    assert @fake_system.received_operation?(:rm_rf, File.join(@home, ".gemini", "extensions", "nanobanana"))
  end

  private

  def create_migration
    Dotfiles::Migration::RemoveRetiredCommandLineTools.new(
      dotfiles_dir: @dotfiles_dir,
      home: @home,
      system: @fake_system
    )
  end

  def formulae
    Dotfiles::Migration::RemoveRetiredCommandLineTools::HOMEBREW_FORMULAE
  end

  def stub_brew_formula(formula, installed:)
    @fake_system.stub_command(brew_command("list", "--formula", formula), "", exit_status: installed ? 0 : 1)
  end

  def brew_command(*args)
    [{"HOMEBREW_NO_AUTO_UPDATE" => "1", "HOMEBREW_NO_ENV_HINTS" => "1"}, "brew", *args]
  end
end
