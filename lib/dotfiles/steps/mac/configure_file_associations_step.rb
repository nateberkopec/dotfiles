class Dotfiles::Step::ConfigureFileAssociationsStep < Dotfiles::Step
  DESCRIPTION = "Sets preferred macOS file associations using duti.".freeze

  macos_only

  def self.display_name
    "File Associations"
  end

  def self.depends_on
    [Dotfiles::Step::InstallSystemPackagesStep, Dotfiles::Step::InstallApplicationsStep]
  end

  def should_run?
    return false if ENV["CI"]
    return false unless allowed_on_platform?
    return false if file_associations.empty?

    !complete?
  end

  def run
    file_associations.each do |bundle_id, extensions|
      extensions.each do |ext|
        debug "Setting #{ext} files to open with #{bundle_id}..."
        execute(command("duti", "-s", bundle_id, ext, "all"))
      end
    end
  end

  def complete?
    return true if ENV["CI"]

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
    output, status = execute(command("duti", "-x", extension))
    return nil unless status == 0
    output.lines.map(&:strip).reject(&:empty?).last
  end
end
