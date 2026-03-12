require "test_helper"

class FixMiseRubygemsPluginStepTest < StepTestCase
  step_class Dotfiles::Step::FixMiseRubygemsPluginStep

  def test_should_run_when_stale_asdf_plugin_is_installed
    @fake_system.stub_file_content(plugin_path, stale_plugin_content)

    assert_should_run
  end

  def test_complete_when_plugin_is_missing
    assert_complete
    refute_should_run
  end

  def test_complete_when_plugin_is_not_the_stale_asdf_plugin
    @fake_system.stub_file_content(plugin_path, replacement_plugin_content)

    assert_complete
    refute_should_run
  end

  def test_run_removes_stale_plugin
    @fake_system.stub_file_content(plugin_path, stale_plugin_content)

    step.run

    assert_command_run(:rm_rf, plugin_path)
  end

  private

  def plugin_path
    File.join(@home, ".local", "share", "mise", "plugins", "ruby", "rubygems-plugin", "rubygems_plugin.rb")
  end

  def stale_plugin_content
    <<~RUBY
      module ReshimInstaller
        def install(options)
          super
          `asdf reshim ruby`
        end
      end
    RUBY
  end

  def replacement_plugin_content
    <<~RUBY
      module ReshimInstaller
        class << self
          def reshim
            `mise reshim`
          end
        end
      end
    RUBY
  end
end
