class Dotfiles::Step::InstallDebianPackagesStep < Dotfiles::Step
  DESCRIPTION = "Configures APT sources needed by mise system packages.".freeze

  CONTAINER_UNSUPPORTED_SOURCES = %w[1password google-chrome].freeze

  debian_only

  def self.display_name
    "Debian Package Sources"
  end

  def should_run?
    missing_sources.any?
  end

  def run
    debian_sources.each { |source| ensure_source(source) }
  end

  def complete?
    super
    missing_sources.each { |message| add_error(message) }
    missing_sources.empty?
  end

  private

  def debian_sources
    sources = @config.debian_sources
    return sources unless skip_unsupported_third_party_debian?

    sources.reject { |source| CONTAINER_UNSUPPORTED_SOURCES.include?(source["name"].to_s) }
  end

  def ensure_source(source)
    [ensure_source_key(source), ensure_source_list(source)].any?
  end

  def ensure_source_key(source)
    key_url = source["key_url"]
    return false unless key_url

    keyring_path = source["signed_by"] || source_keyring_path(source)
    return false if @system.file_exist?(keyring_path)

    tmp = temp_path("apt-key")
    output, status = execute(command("curl", "-fsSL", key_url, "-o", tmp))
    unless status == 0
      add_warning(title: "⚠️  Debian Source Key Download Failed", message: "Failed to download key from #{key_url}\n#{output}")
      @system.rm_rf(tmp)
      return false
    end

    unless command_exists?("gpg")
      add_warning(title: "⚠️  Debian Source Key Skipped", message: "gpg not available; cannot install key for #{key_url}")
      @system.rm_rf(tmp)
      return false
    end

    output, status = execute(sudo_command("gpg", "--dearmor", "-o", keyring_path, tmp))
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Key Install Failed", message: "Failed to install keyring at #{keyring_path}\n#{output}") unless status == 0
    status == 0
  end

  def ensure_source_list(source)
    list_path = source_list_path(source)
    expected = source_line(source)
    return false unless expected
    return false if current_sources(list_path).include?(expected)

    tmp = temp_path("apt-source")
    @system.write_file(tmp, expected + "\n")
    output, status = execute(sudo_command("install", "-m", "644", tmp, list_path))
    @system.rm_rf(tmp)
    add_warning(title: "⚠️  Debian Source Install Failed", message: "Failed to install #{list_path}\n#{output}") unless status == 0
    status == 0
  end

  def source_line(source)
    return source["line"] if source["line"]
    return nil unless source["repo"]

    signed_by = source_keyring_for(source)
    options = signed_by ? " [signed-by=#{signed_by}]" : ""
    components = Array(source.fetch("components", ["main"])).join(" ")
    "deb#{options} #{source["repo"]} #{source.fetch("suite", "stable")} #{components}"
  end

  def missing_sources
    debian_sources.flat_map { |source| missing_source_entries(source) }
  end

  def missing_source_entries(source)
    list_path = source_list_path(source)
    expected = source_line(source)
    missing_source_list_entries(list_path, expected) + missing_source_key_entries(source)
  end

  def missing_source_list_entries(list_path, expected)
    return [] unless expected
    return ["APT source missing: #{list_path}"] unless @system.file_exist?(list_path)
    return [] if current_sources(list_path).include?(expected)

    ["APT source mismatch: #{list_path}"]
  end

  def current_sources(list_path)
    return [] unless @system.file_exist?(list_path)

    @system.read_file(list_path).lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
  end

  def missing_source_key_entries(source)
    signed_by = source_keyring_for(source)
    return [] unless signed_by
    return [] if @system.file_exist?(signed_by)

    ["APT keyring missing: #{signed_by}"]
  end

  def source_keyring_for(source)
    source["signed_by"] || (source["key_url"] ? source_keyring_path(source) : nil)
  end

  def source_list_path(source)
    "/etc/apt/sources.list.d/#{source.fetch("name", "dotfiles")}.list"
  end

  def source_keyring_path(source)
    "/usr/share/keyrings/#{source.fetch("name", "dotfiles")}-archive-keyring.gpg"
  end

  def skip_unsupported_third_party_debian?
    (@system.respond_to?(:running_container?) && @system.running_container?) || ENV["GITHUB_ACTIONS"] == "true"
  end
end
