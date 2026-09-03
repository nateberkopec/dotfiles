require "toml-rb"

module OmniWMSettingsHelper
  def settings
    @settings ||= TomlRB.load_file(File.expand_path("../../files/home/.config/omniwm/settings.toml", __dir__))
  end
end
