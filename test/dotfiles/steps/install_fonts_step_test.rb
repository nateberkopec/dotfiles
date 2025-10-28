require "test_helper"
require "shellwords"

class InstallFontsStepTest < Minitest::Test
  def setup
    super
    @step = create_step(Dotfiles::Step::InstallFontsStep)
    @font_dir = File.join(@dotfiles_dir, "fonts")
  end

  def test_should_not_run_in_ci
    ENV["CI"] = "true"

    step = create_step(Dotfiles::Step::InstallFontsStep)
    refute step.should_run?
  ensure
    ENV.delete("CI")
  end

  def test_should_not_run_in_noninteractive
    ENV["NONINTERACTIVE"] = "true"

    step = create_step(Dotfiles::Step::InstallFontsStep)
    refute step.should_run?
  ensure
    ENV.delete("NONINTERACTIVE")
  end

  def test_should_run_returns_false_when_no_fonts_in_directory
    @fake_system.stub_command_output("fc-list", "")

    refute @step.should_run?
  end

  def test_should_run_returns_false_when_all_fonts_installed
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_command_output("fc-list", "TestFont.ttf\nOtherFont.ttf")

    refute @step.should_run?
  end

  def test_should_run_returns_true_when_fonts_missing
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_command_output("fc-list", "OtherFont.ttf")

    assert @step.should_run?
  end

  def test_should_run_checks_multiple_fonts
    font1 = File.join(@font_dir, "Font1.ttf")
    font2 = File.join(@font_dir, "Font2.ttf")
    @fake_system.stub_file_content(font1, "font1 data")
    @fake_system.stub_file_content(font2, "font2 data")
    @fake_system.stub_command_output("fc-list", "Font1.ttf")

    assert @step.should_run?
  end

  def test_run_installs_all_ttf_fonts
    font1 = File.join(@font_dir, "Font1.ttf")
    font2 = File.join(@font_dir, "Font2.ttf")
    @fake_system.stub_file_content(font1, "font1 data")
    @fake_system.stub_file_content(font2, "font2 data")
    @fake_system.stub_command_output("open #{Shellwords.escape(font1)}", "")
    @fake_system.stub_command_output("open #{Shellwords.escape(font2)}", "")

    @step.run

    assert @fake_system.received_operation?(:execute, "open #{Shellwords.escape(font1)}", {quiet: true})
    assert @fake_system.received_operation?(:execute, "open #{Shellwords.escape(font2)}", {quiet: true})
  end

  def test_run_handles_fonts_with_special_characters
    font_path = File.join(@font_dir, "Font With Spaces.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_command_output("open #{Shellwords.escape(font_path)}", "")

    @step.run

    assert @fake_system.received_operation?(:execute, "open #{Shellwords.escape(font_path)}", {quiet: true})
  end

  def test_complete_returns_false_when_fc_list_fails
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_execute_result("fc-list", ["error", 1])

    refute @step.complete?
  end

  def test_complete_returns_true_when_all_fonts_installed
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_execute_result("fc-list", ["TestFont installed", 0])

    assert @step.complete?
  end

  def test_complete_returns_false_when_fonts_missing
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_execute_result("fc-list", ["OtherFont installed", 0])

    refute @step.complete?
  end

  def test_complete_returns_nil_in_ci_when_fonts_missing
    ENV["CI"] = "true"
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_execute_result("fc-list", ["OtherFont installed", 0])

    assert_nil @step.complete?
  ensure
    ENV.delete("CI")
  end

  def test_complete_returns_nil_in_noninteractive_when_fonts_missing
    ENV["NONINTERACTIVE"] = "true"
    font_path = File.join(@font_dir, "TestFont.ttf")
    @fake_system.stub_file_content(font_path, "font data")
    @fake_system.stub_execute_result("fc-list", ["OtherFont installed", 0])

    assert_nil @step.complete?
  ensure
    ENV.delete("NONINTERACTIVE")
  end

  def test_complete_returns_true_when_no_fonts_to_install
    @fake_system.stub_execute_result("fc-list", ["", 0])

    assert @step.complete?
  end

  def test_update_creates_destination_directory
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")

    @step.update

    assert @fake_system.received_operation?(:mkdir_p, dest_dir)
  end

  def test_update_returns_early_when_no_tracked_fonts
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")

    @step.update

    assert_equal 1, @fake_system.operation_count(:mkdir_p)
    assert_equal 0, @fake_system.operation_count(:cp)
  end

  def test_update_copies_tracked_fonts_from_user_library
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "TrackedFont.ttf")
    user_fonts_dir = File.expand_path("~/Library/Fonts")
    src_font = File.join(user_fonts_dir, "TrackedFont.ttf")

    @fake_system.mkdir_p(user_fonts_dir)
    @fake_system.stub_file_content(tracked_font, "old font")
    @fake_system.stub_file_content(src_font, "new font")

    @step.update

    assert @fake_system.received_operation?(:cp, src_font, File.join(dest_dir, "TrackedFont.ttf"))
  end

  def test_update_copies_tracked_fonts_from_system_library
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "TrackedFont.ttf")
    system_fonts_dir = "/Library/Fonts"
    src_font = File.join(system_fonts_dir, "TrackedFont.ttf")

    @fake_system.mkdir_p(system_fonts_dir)
    @fake_system.stub_file_content(tracked_font, "old font")
    @fake_system.stub_file_content(src_font, "new font")

    @step.update

    assert @fake_system.received_operation?(:cp, src_font, File.join(dest_dir, "TrackedFont.ttf"))
  end

  def test_update_prefers_user_library_over_system_library
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "TrackedFont.ttf")
    user_fonts_dir = File.expand_path("~/Library/Fonts")
    system_fonts_dir = "/Library/Fonts"
    user_src = File.join(user_fonts_dir, "TrackedFont.ttf")
    system_src = File.join(system_fonts_dir, "TrackedFont.ttf")

    @fake_system.mkdir_p(user_fonts_dir)
    @fake_system.mkdir_p(system_fonts_dir)
    @fake_system.stub_file_content(tracked_font, "old font")
    @fake_system.stub_file_content(user_src, "user font")
    @fake_system.stub_file_content(system_src, "system font")

    @step.update

    assert @fake_system.received_operation?(:cp, user_src, File.join(dest_dir, "TrackedFont.ttf"))
    refute @fake_system.received_operation?(:cp, system_src, File.join(dest_dir, "TrackedFont.ttf"))
  end

  def test_update_skips_fonts_not_found_in_system
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "MissingFont.ttf")

    @fake_system.stub_file_content(tracked_font, "old font")

    @step.update

    assert_equal 0, @fake_system.operation_count(:cp)
  end

  def test_update_handles_otf_fonts
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "TrackedFont.otf")
    user_fonts_dir = File.expand_path("~/Library/Fonts")
    src_font = File.join(user_fonts_dir, "TrackedFont.otf")

    @fake_system.mkdir_p(user_fonts_dir)
    @fake_system.stub_file_content(tracked_font, "old font")
    @fake_system.stub_file_content(src_font, "new font")

    @step.update

    assert @fake_system.received_operation?(:cp, src_font, File.join(dest_dir, "TrackedFont.otf"))
  end

  def test_update_skips_nonexistent_system_font_directories
    dest_dir = File.join(@dotfiles_dir, "files", "fonts")
    tracked_font = File.join(dest_dir, "TrackedFont.ttf")

    @fake_system.stub_file_content(tracked_font, "old font")

    @step.update

    assert_equal 0, @fake_system.operation_count(:cp)
  end
end
