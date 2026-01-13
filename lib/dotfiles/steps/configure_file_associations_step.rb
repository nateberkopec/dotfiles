class Dotfiles::Step::ConfigureFileAssociationsStep < Dotfiles::Step
  macos_only

  def self.display_name
    "File Associations"
  end

  def self.depends_on
    [Dotfiles::Step::InstallBrewPackagesStep]
  end

  def run
    file_associations.each do |bundle_id, extensions|
      extensions.each do |ext|
        debug "Setting #{ext} files to open with #{bundle_id}..."
        execute("duti -s #{bundle_id} #{ext} all")
      end
    end
  end

  def complete?
    super
    file_associations.each do |bundle_id, extensions|
      extensions.each do |ext|
        add_error("#{ext} not set to open with #{bundle_id}") unless current_handler(ext) == bundle_id
      end
    end
    @errors.empty?
  end

  private

  def file_associations
    @config["file_associations"] || {}
  end

  def current_handler(extension)
    output, status = execute("duti -x #{extension} 2>/dev/null")
    return nil unless status == 0
    output.lines.find { |line| line.include?("Bundle ID") }&.split(":")&.last&.strip
  end
end
