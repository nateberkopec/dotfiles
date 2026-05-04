require "test_helper"
require_relative "support/bootstrap_script_helper"
require_relative "support/bootstrap_ruby_script_helper"

class BootstrapRubyTest < Minitest::Test
  include BootstrapScriptHelper
  include BootstrapRubyScriptHelper

  def test_bootstrap_ruby_installs_homebrew_libyaml_before_mise_install
    with_bootstrap_stub do |env|
      write_ruby_build_stubs(env)
      run_bootstrap_ruby_for_macos(env)

      assert_ordered_command env, "brew install libyaml", mise_install_with_libyaml(env)
    end
  end

  def test_bootstrap_ruby_preserves_existing_ruby_configure_opts
    with_bootstrap_stub do |env|
      write_ruby_build_stubs(env)
      run_bootstrap_ruby_for_macos(env.merge("RUBY_CONFIGURE_OPTS" => "--disable-install-doc"))

      assert_ordered_command env, "brew install libyaml", mise_install_with_existing_opts(env)
    end
  end
end
