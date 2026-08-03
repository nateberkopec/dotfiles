require "test_helper"

class PlatformRestrictableTest < Minitest::Test
  def setup
    super
    @original_steps = Dotfiles::Step.class_variable_get(:@@steps).dup
    @original_migrations = Dotfiles::Migration.class_variable_get(:@@migrations).dup
  end

  def teardown
    Dotfiles::Step.class_variable_set(:@@steps, @original_steps)
    Dotfiles::Migration.class_variable_set(:@@migrations, @original_migrations)
    super
  end

  def test_unrestricted_instances_are_allowed
    assert_platform_access
  end

  def test_macos_only_instances_are_allowed_only_on_macos
    assert_platform_access(restrictions: [:macos], expected: false)
    assert_platform_access(restrictions: [:macos], macos: true)
  end

  def test_debian_only_instances_are_allowed_only_on_debian
    assert_platform_access(restrictions: [:debian], expected: false)
    assert_platform_access(restrictions: [:debian], debian: true)
  end

  def test_dual_restricted_instances_require_both_platforms
    assert_platform_access(restrictions: [:macos, :debian], expected: false)
    assert_platform_access(restrictions: [:macos, :debian], macos: true, expected: false)
    assert_platform_access(restrictions: [:macos, :debian], debian: true, expected: false)
    assert_platform_access(restrictions: [:macos, :debian], macos: true, debian: true)
  end

  private

  def assert_platform_access(restrictions: [], macos: false, debian: false, expected: true)
    [Dotfiles::Step, Dotfiles::Migration].each do |base|
      system = FakeSystemAdapter.new
      system.stub_macos(macos)
      system.stub_debian(debian)
      instance = platform_restricted_instance(base, restrictions, system)

      assert_equal expected, instance.allowed_on_platform?, base.name
    end
  end

  def platform_restricted_instance(base, restrictions, system)
    subclass = Class.new(base)
    restrictions.each { |platform| subclass.public_send("#{platform}_only") }
    return create_step(subclass, system: system, config: Object.new) if base == Dotfiles::Step

    subclass.new(dotfiles_dir: @dotfiles_dir, home: @home, system: system)
  end
end
