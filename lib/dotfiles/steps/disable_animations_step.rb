class Dotfiles::Step::DisableAnimationsStep < Dotfiles::Step
  include Dotfiles::Step::Defaultable

  def run
    setting_entries.each do |domain, key, value|
      domain_flag = domain_flag_for(domain)
      type_flag = type_flag_for(value)
      execute("defaults write #{domain_flag} #{key} #{type_flag} #{value}")
    end
    execute("killall Dock")
    execute("killall Finder")
  end

  def complete?
    setting_entries.all? do |domain, key, expected_value|
      defaults_read_equals?(build_read_command(domain, key), expected_value.to_s)
    end
  end

  def update
    update_defaults_config("animation_settings", "animations.yml")
  end

  private

  def animation_settings
    @config.load_config("animations.yml").fetch("animation_settings", {})
  end

  def setting_entries
    animation_settings.flat_map do |domain, settings|
      settings.map { |key, value| [domain, key, value] }
    end
  end

  def type_flag_for(value)
    case value
    when 0, 1
      "-int"
    when Float
      "-float"
    else
      "-int"
    end
  end
end
