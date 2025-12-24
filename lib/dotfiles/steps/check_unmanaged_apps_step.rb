class Dotfiles::Step::CheckUnmanagedAppsStep < Dotfiles::Step
  def should_run?
    missing_apps.any?
  end

  def run
    apps = missing_apps
    return if apps.empty?

    add_notice(
      title: "📦 Missing Applications",
      message: apps.map { |path| "#{app_name(path)} (#{path})" }.join("\n")
    )
  end

  def complete?
    super
    true
  end

  private

  def missing_apps
    unmanaged_apps.reject do |path|
      skipped_apps.include?(app_name(path)) || @system.dir_exist?(path) || homebrew_managed?(path)
    end
  end

  def unmanaged_apps
    @config.unmanaged_apps || []
  end

  def homebrew_managed?(path)
    homebrew_paths.include?(path)
  end

  def homebrew_paths
    @config.packages.fetch("applications", []).map { |app| app["path"] }
  end

  def app_name(path)
    path.split("/").last.sub(/\.app$/, "")
  end

  def skipped_apps
    skipped_apps_path = File.join(@dotfiles_dir, ".skipped-apps")
    return [] unless @system.file_exist?(skipped_apps_path)

    @system.read_file(skipped_apps_path).split("\n").map(&:strip).reject(&:empty?)
  end
end
