require "test_helper"

class InstallFontsStepTest < StepTestCase
  step_class Dotfiles::Step::InstallFontsStep

  def test_should_not_run_in_ci_or_noninteractive
    with_env("CI" => "true") { refute_should_run }
    with_env("NONINTERACTIVE" => "true") { refute_should_run }
  end

  def test_should_run_when_fonts_missing
    prepare_fonts(["JetBrainsMono-Regular.ttf"])
    stub_installed_fonts("")
    assert_should_run
  end

  def test_should_not_run_when_all_fonts_present
    prepare_fonts(["JetBrainsMono-Regular.ttf"])
    stub_font_present("JetBrainsMono-Regular")
    refute_should_run
  end

  def test_run_opens_each_font_file
    font = "JetBrainsMono-Regular.ttf"
    prepare_fonts([font])
    step.run
    assert_executed("open #{@dotfiles_dir}/fonts/#{font}")
  end

  def test_complete_when_fonts_installed
    prepare_fonts(["JetBrainsMono-Regular.ttf"])
    stub_font_present("JetBrainsMono-Regular")
    assert_complete
  end

  def test_incomplete_when_font_missing
    prepare_fonts(["JetBrainsMono-Regular.ttf"])
    stub_installed_fonts("")
    assert_incomplete
  end

  private

  def prepare_fonts(fonts)
    fonts.each do |font|
      @fake_system.filesystem[File.join(@dotfiles_dir, "fonts", font)] = "font data"
    end
  end

  def stub_installed_fonts(list, status: 0)
    @fake_system.stub_command("fc-list", [list, status])
  end

  def stub_font_present(name)
    stub_installed_fonts("#{name}.ttf\n#{name}")
  end

  def with_env(vars)
    originals = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    begin
      rebuild_step!
      yield
    ensure
      vars.each_key { |k| originals[k].nil? ? ENV.delete(k) : ENV[k] = originals[k] }
      rebuild_step!
    end
  end
end
