class Dotfiles::Step::InstallGeminiNanobananaExtensionStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  def self.depends_on
    Dotfiles::Step.system_packages_steps
  end

  def should_run?
    return false unless command_exists?("gemini")
    !extension_installed?
  end

  def run
    return unless command_exists?("gemini")

    install_extension unless extension_installed?
  end

  def complete?
    super
    return true unless command_exists?("gemini")
    add_error("Nano Banana extension not installed at #{extension_path}") unless extension_installed?
    @errors.empty?
  end

  private

  def extension_path
    File.join(@home, ".gemini", "extensions", "nanobanana")
  end

  def extension_installed?
    @system.dir_exist?(extension_path)
  end

  def install_extension
    execute("gemini extensions install https://github.com/gemini-cli-extensions/nanobanana --consent")
  end
end
