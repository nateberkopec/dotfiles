require "securerandom"

class Dotfiles::Step::InstallDebianNonAptPackagesStep < Dotfiles::Step
  debian_only

  CARGO_PACKAGES = {
    "broot" => "broot",
    "difftastic" => "difftastic",
    "starship" => "starship"
  }.freeze
  YQ_ASSETS = {
    "x86_64" => "yq_linux_amd64",
    "aarch64" => "yq_linux_arm64",
    "arm64" => "yq_linux_arm64"
  }.freeze

  def self.display_name
    "Debian Non-Apt Packages"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    missing_packages.any?
  end

  def run
    install_cargo_packages
    install_yq if configured_packages.include?("yq")
    @configured_packages = @missing_packages = nil
  end

  def complete?
    super
    missing_packages.each { |pkg| add_error("Non-APT package not installed: #{pkg}") }
    missing_packages.empty?
  end

  private

  def configured_packages
    @configured_packages ||= @config.debian_non_apt_packages
  end

  def missing_packages
    @missing_packages ||= configured_packages.reject { |pkg| package_installed?(pkg) }
  end

  def package_installed?(pkg)
    command = if pkg == "difftastic"
      "difft"
    else
      pkg
    end
    bin_paths = [File.join(@home, ".local", "bin", command), File.join(@home, ".cargo", "bin", command)]
    command_exists?(command) || bin_paths.any? { |path| @system.file_exist?(path) }
  end

  def install_cargo_packages
    packages = configured_packages.select { |pkg| CARGO_PACKAGES.key?(pkg) && !package_installed?(pkg) }
    return if packages.empty?
    cargo = cargo_command
    unless cargo
      add_error("cargo not available; cannot install #{packages.join(", ")}")
      return
    end
    packages.each { |pkg| install_cargo_package(cargo, pkg) }
  end

  def install_cargo_package(cargo, pkg)
    crate = CARGO_PACKAGES.fetch(pkg)
    output, status = execute("#{cargo} install --locked --root #{File.join(@home, ".local")} #{crate}")
    add_error("cargo install #{crate} failed (status #{status}): #{output}") unless status == 0
  end

  def cargo_command
    cargo_path = File.join(@home, ".cargo", "bin", "cargo")
    return cargo_path if @system.file_exist?(cargo_path)
    return cargo_path if install_rustup
    return "cargo" if command_exists?("cargo")
    nil
  end

  def install_rustup
    tmp = temp_path("rustup")
    output, status = execute("curl -fsSL https://sh.rustup.rs -o #{tmp}")
    if status != 0
      add_error("rustup download failed (status #{status}): #{output}")
      @system.rm_rf(tmp)
      return false
    end
    output, status = execute("sh #{tmp} -y --profile minimal --no-modify-path")
    @system.rm_rf(tmp)
    add_error("rustup install failed (status #{status}): #{output}") unless status == 0
    status == 0
  end

  def install_yq
    return if package_installed?("yq")
    asset = YQ_ASSETS[system_arch]
    unless asset
      add_error("Unsupported architecture for yq: #{system_arch}")
      return
    end
    tmp = temp_path("yq")
    output, status = execute("curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/#{asset} -o #{tmp}")
    if status != 0
      add_error("yq download failed (status #{status}): #{output}")
      @system.rm_rf(tmp)
      return
    end
    dest = File.join(@home, ".local", "bin", "yq")
    @system.mkdir_p(File.dirname(dest))
    output, status = execute("install -m 755 #{tmp} #{dest}")
    @system.rm_rf(tmp)
    add_error("yq install failed (status #{status}): #{output}") unless status == 0
  end

  def system_arch
    return @system_arch if defined?(@system_arch)
    output, status = @system.execute("uname -m")
    @system_arch = if status == 0
      output.strip
    else
      ""
    end
  end

  def temp_path(label)
    File.join("/tmp", "dotfiles-#{label}-#{SecureRandom.hex(6)}")
  end
end
