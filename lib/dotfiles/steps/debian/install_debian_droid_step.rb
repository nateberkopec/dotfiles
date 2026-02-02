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

  def install
    return if installed?
    output, status = execute("curl -fsSL #{DROID_INSTALL_URL} | sh")
    add_error("Droid install failed (status #{status}): #{output}") unless status == 0
  end
end
