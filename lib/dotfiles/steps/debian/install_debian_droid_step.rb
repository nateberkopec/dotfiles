class Dotfiles::Step::InstallDebianDroidStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptStep

  DROID_INSTALL_URL = "https://app.factory.ai/cli".freeze

  def self.display_name
    "Factory Droid"
  end

  private

  def package_name
    "droid"
  end

  def install_script_url
    DROID_INSTALL_URL
  end

  def install_error_label
    "Droid"
  end
end
