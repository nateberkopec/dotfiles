class Dotfiles::Step::InstallDebianCargoPackagesStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptHelper

  debian_only

  def self.display_name
    "Debian Cargo Packages"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    missing_packages.any?
  end

  def run
    install_cargo_packages
    reset_cache
  end

  def complete?
    super
    return true if configured_packages.empty?
    missing_packages.each { |pkg| add_error("Non-APT package not installed: #{pkg}") }
    missing_packages.empty?
  end

  private

  def configured_packages
    @configured_packages ||= @config.debian_non_apt_packages & cargo_packages.keys
  end

  def missing_packages
    @missing_packages ||= configured_packages.reject { |pkg| package_installed?(pkg, command: cargo_command_name(pkg)) }
  end

  def cargo_command_name(pkg)
    return "difft" if pkg == "difftastic"
    pkg
  end

  def install_cargo_packages
    return if configured_packages.empty?
    cargo = cargo_command
    unless cargo
      add_error("cargo not available; cannot install #{configured_packages.join(", ")}")
      return
    end
    configured_packages.each { |pkg| install_cargo_package(cargo, pkg) }
  end

  def install_cargo_package(cargo, pkg)
    crate = cargo_packages.fetch(pkg)
    output, status = execute(
      "#{cargo} install --locked --root #{File.join(@home, ".local")} #{crate}",
      quiet: !@debug
    )
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

  def cargo_packages
    @cargo_packages ||= begin
      raw = @config.fetch("debian_non_apt_cargo_packages", [])
      case raw
      when Hash
        raw.transform_keys(&:to_s)
      when Array
        raw.map { |item| [item.to_s, item.to_s] }.to_h
      else
        {}
      end
    end
  end

  def reset_cache
    @configured_packages = nil
    @missing_packages = nil
  end
end
