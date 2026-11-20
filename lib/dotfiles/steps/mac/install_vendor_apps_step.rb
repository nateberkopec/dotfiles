class Dotfiles::Step::InstallVendorAppsStep < Dotfiles::Step
  DESCRIPTION = "Installs macOS apps from their vendors' signed releases; the apps update themselves afterward.".freeze

  macos_only

  def initialize(**kwargs)
    super
    @install_failures = {}
  end

  def should_run?
    !ENV["CI"] && allowed_on_platform? && !complete?
  end

  def run
    return if ENV["CI"] || !allowed_on_platform?

    apps.each do |app|
      install(app) unless installed?(app)
      link_commands(app) if installed?(app)
    end
  end

  def complete?
    super
    return true if ENV["CI"] || !allowed_on_platform?

    apps.each do |app|
      name = app.fetch("name")
      if !installed?(app)
        add_error(@install_failures.fetch(name, "#{name}.app is not installed in Applications"))
      elsif !commands(app).all? { |link, target| linked?(link, target) }
        add_error("#{name} commands are not linked into ~/.local/bin")
      end
    end
    errors.empty?
  end

  private

  def apps
    all = @config.fetch("vendor_apps", [])
    user_has_admin_rights? ? all : all.reject { |app| app["admin_only"] }
  end

  def install(app)
    name = app.fetch("name")
    archive = temp_path("vendor-app-archive")
    contents = temp_path("vendor-app-contents")
    download(app, archive)
    copy_verified_app(app, archive, contents)
    @install_failures.delete(name)
    add_notice(title: "#{name} setup", message: "Open #{name} to finish setting it up.")
  rescue => error
    @install_failures[name] = "#{name}: #{error.message}"
  ensure
    @system.rm_rf(archive)
    @system.rm_rf(contents)
  end

  def download(app, archive)
    run!("download failed", "curl", "-fsSL", "--retry", "2", "-o", archive, app.fetch("url"))
  end

  def copy_verified_app(app, archive, contents)
    @system.mkdir_p(contents)
    dmg = app.fetch("archive") == "dmg"
    if dmg
      run!("could not mount the release", "/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", contents, archive)
    else
      run!("could not unpack the release", "/usr/bin/ditto", "-x", "-k", archive, contents)
    end
    copy_app(app, File.join(contents, "#{app.fetch("name")}.app"))
  ensure
    execute(command("/usr/bin/hdiutil", "detach", contents)) if dmg
  end

  def copy_app(app, source)
    team_id = app.fetch("team_id")
    requirement = %(anchor apple generic and certificate leaf[subject.OU] = "#{team_id}")
    run!("release is not signed by team #{team_id}", "/usr/bin/codesign", "--verify", "--deep", "-R=#{requirement}", source)
    @system.mkdir_p(File.dirname(destination(app)))
    run!("could not copy the release into Applications", "/usr/bin/ditto", source, destination(app))
  end

  def run!(failure, *argv)
    _output, status = execute(command(*argv))
    raise failure unless status == 0
  end

  def link_commands(app)
    commands(app).each do |link, target|
      next if linked?(link, target)

      @system.mkdir_p(File.dirname(link))
      execute(command("ln", "-sfn", target, link))
    end
  end

  def commands(app)
    app.fetch("commands", {}).to_h { |name, path| [File.join(@home, ".local", "bin", name), File.join(destination(app), path)] }
  end

  def linked?(link, target)
    @system.symlink?(link) && @system.realpath(link) == @system.realpath(target)
  rescue Errno::ENOENT
    false
  end

  def installed?(app)
    @system.file_exist?(File.join(destination(app), "Contents", "Info.plist"))
  end

  def destination(app)
    directory = user_has_admin_rights? ? "/Applications" : File.join(@home, "Applications")
    File.join(directory, "#{app.fetch("name")}.app")
  end
end
