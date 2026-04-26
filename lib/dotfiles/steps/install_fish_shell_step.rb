class Dotfiles::Step::InstallFishShellStep < Dotfiles::Step
  DESCRIPTION = "Installs Fish shell and links bundled helper commands.".freeze

  FISH_TOOL = "github:fish-shell/fish-shell".freeze
  FISH_VERSION = "latest".freeze

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    supported_platform? && !mise_offline? && (install_needed? || !fish_linked?)
  end

  def run
    return add_error("mise not available; cannot install fish shell") unless mise_available?
    return add_error("Unsupported fish shell platform: #{platform_description}") unless fish_tool_spec

    install_fish
    link_fish_binaries if install_errors.empty?
  end

  def complete?
    super
    return true unless supported_platform?

    install_errors.each { |message| add_error(message) }
    add_error("Fish shell is not linked at #{fish_link_path}") unless fish_linked?
    @errors.empty?
  end

  private

  def install_fish
    output, status = execute(install_command)
    return if status == 0

    install_errors << format_command_error(install_command, status, output)
  end

  def link_fish_binaries
    binary_targets.each do |name, target|
      next link_binary(name, target) if target

      install_errors << "Unable to find installed fish binary #{name.inspect} under #{fish_install_prefix}"
    end
  end

  def link_binary(name, target)
    link_path = File.join(local_bin_dir, name)
    @system.mkdir_p(local_bin_dir)
    @system.rm_rf(link_path) if @system.file_exist?(link_path) || @system.symlink?(link_path)
    @system.create_symlink(target, link_path)
  end

  def binary_targets
    fish_binary_globs.to_h do |name, patterns|
      [name, binary_target_for(patterns)]
    end
  end

  def binary_target_for(patterns)
    Array(patterns).filter_map { |pattern| @system.glob(File.join(fish_install_prefix, pattern)).first }.first
  end

  def fish_binary_globs
    if @system.macos?
      {
        "fish" => macos_binary_globs("fish"),
        "fish_indent" => macos_binary_globs("fish_indent"),
        "fish_key_reader" => macos_binary_globs("fish_key_reader")
      }
    else
      {"fish" => "fish"}
    end
  end

  def macos_binary_globs(name)
    [
      "Contents/Resources/base/usr/local/bin/#{name}",
      "fish-*.app/Contents/Resources/base/usr/local/bin/#{name}"
    ]
  end

  def install_needed?
    mise_available? && fish_tool_spec && begin
      output, status = execute(install_command(dry_run: true))
      status != 0 || output.to_s.lines.any? { |line| line.include?("would install") }
    end
  end

  def fish_linked?
    @system.file_exist?(fish_link_path) || @system.symlink?(fish_link_path)
  end

  def fish_install_prefix
    @fish_install_prefix ||= begin
      output, status = execute(where_command)
      return "" unless status == 0

      output.strip
    end
  end

  def fish_link_path
    File.join(local_bin_dir, "fish")
  end

  def local_bin_dir
    File.join(@home, ".local", "bin")
  end

  def install_command(dry_run: false)
    args = ["install", "--yes"]
    args << "--dry-run" if dry_run
    mise_command(*args, fish_tool_spec)
  end

  def where_command
    mise_command("where", "#{FISH_TOOL}@#{FISH_VERSION}")
  end

  def mise_command(*args)
    command("mise", "--cd", @home, *args)
  end

  def fish_tool_spec
    return macos_fish_tool_spec if @system.macos?
    linux_fish_tool_spec if @system.linux?
  end

  def macos_fish_tool_spec
    "#{FISH_TOOL}[asset_pattern=fish-{{version}}.app.zip]@#{FISH_VERSION}"
  end

  def linux_fish_tool_spec
    return unless linux_asset_arch

    "#{FISH_TOOL}[asset_pattern=fish-{{version}}-linux-#{linux_asset_arch}.tar.xz]@#{FISH_VERSION}"
  end

  def linux_asset_arch
    @linux_asset_arch ||= begin
      arch, status = execute(command("uname", "-m"), quiet: true)
      normalized_linux_arch(arch.strip) if status == 0
    end
  end

  def normalized_linux_arch(arch)
    case arch
    when "x86_64", "amd64"
      "x86_64"
    when "aarch64", "arm64"
      "aarch64"
    end
  end

  def supported_platform?
    @system.macos? || @system.linux?
  end

  def platform_description
    output, status = execute(command("uname", "-sm"), quiet: true)
    return output.strip if status == 0 && !output.strip.empty?

    RUBY_PLATFORM
  end

  def mise_available?
    command_exists?("mise")
  end

  def mise_offline?
    ENV["MISE_OFFLINE"] == "1"
  end

  def install_errors
    @install_errors ||= []
  end
end
