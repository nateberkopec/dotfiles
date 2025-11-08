class Dotfiles::Step::CreateStandardFoldersStep < Dotfiles::Step
  def run
    debug "Creating standard folders..."
    standard_folders.each do |folder|
      folder_path = @system.path_join(@home, folder)
      @system.mkdir_p(folder_path)
    end
  end

  def complete?
    standard_folders.all? do |folder|
      folder_path = @system.path_join(@home, folder)
      @system.dir_exist?(folder_path)
    end
  end

  private

  def standard_folders
    @standard_folders ||= folders_config.fetch("standard_folders", [])
  end

  def folders_config
    @folders_config ||= @config.load_config("folders.yml")
  end
end
