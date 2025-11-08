class Dotfiles::Step::CheckNonHomebrewAppsStep < Dotfiles::Step
  def run
    missing_apps.each do |path|
      add_notice(
        title: "📦 Missing Application: #{app_name(path)}",
        message: "Expected path: #{path}"
      )
    end
  end

  def complete?
    true
  end

  private

  def missing_apps
    non_homebrew_apps.reject do |path|
      skipped_apps.include?(app_name(path)) || @system.dir_exist?(path) || homebrew_managed?(path)
    end
  end

  def non_homebrew_apps
    @config.non_homebrew_apps || []
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
    skipped_apps_path = @system.path_join(@dotfiles_dir, ".skipped-apps")
    return [] unless @system.file_exist?(skipped_apps_path)

    @system.read_file(skipped_apps_path).split("\n").map(&:strip).reject(&:empty?)
  end
end
