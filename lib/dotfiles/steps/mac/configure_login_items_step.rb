class Dotfiles::Step::ConfigureLoginItemsStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def should_run?
    !all_login_items_configured?
  end

  def run
    debug "Configuring login items..."
    current_items = current_login_item_paths
    login_items.each do |app_path|
      next if current_items.include?(app_path)
      next unless @system.dir_exist?(app_path)
      add_login_item(app_path)
    end
  end

  def complete?
    super
    all_login_items_configured?
  end

  private

  def login_items
    @config.fetch("login_items", [])
  end

  def all_login_items_configured?
    return true if login_items.empty?
    current_items = current_login_item_paths
    login_items.all? do |app_path|
      !@system.dir_exist?(app_path) || current_items.include?(app_path)
    end
  end

  def current_login_item_paths
    script = 'tell application "System Events" to get the path of every login item'
    output, status = execute("osascript -e '#{script}'", quiet: true)
    return [] unless status == 0
    output.split(", ").map(&:strip)
  end

  def add_login_item(app_path)
    debug "Adding #{app_path} to login items..."
    script = "tell application \"System Events\" to make login item at end with properties {path:\"#{app_path}\", hidden:false}"
    execute("osascript -e '#{script}'", quiet: true)
  end
end
