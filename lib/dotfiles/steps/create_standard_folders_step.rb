class Dotfiles::Step::CreateStandardFoldersStep < Dotfiles::Step
  def run
    debug "Creating standard folders..."
    standard_folders.each do |folder|
      folder_path = File.join(@home, folder)
      @system.mkdir_p(folder_path)
    end
  end

  def complete?
    super
    standard_folders.each do |folder|
      folder_path = File.join(@home, folder)
      add_error("Standard folder '#{folder}' does not exist at #{folder_path}") unless @system.dir_exist?(folder_path)
    end
    @errors.empty?
  end

  private

  def standard_folders
    @standard_folders ||= @config.fetch("standard_folders", [])
  end
end
