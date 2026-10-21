class Dotfiles::Step::DistrustCompromisedEmudhraRootsStep < Dotfiles::Step
  DESCRIPTION = "Removes compromised eMudhra trust roots from the macOS CA bundle.".freeze

  CERT_PATH = "/etc/ssl/cert.pem".freeze
  BACKUP_PATH = "/etc/ssl/cert.pem.bak".freeze
  ROOT_HEADING_PATTERN = %r{^=== .*/CN=(?:AAA Certificate Services|emSign ECC Root CA - G3)$}

  prepend Dotfiles::Step::Sudoable

  macos_only

  def should_run?
    affected?
  end

  def run
    unless @system.file_exist?(BACKUP_PATH)
      _, status = execute(command("cp", "-p", CERT_PATH, BACKUP_PATH), sudo: true)
      return add_error("Failed to back up #{CERT_PATH}") unless status.zero?
    end

    filtered_path = temp_path("cert.pem")
    @system.write_file(filtered_path, filtered_bundle)
    _, status = execute(command("install", "-o", "root", "-g", "wheel", "-m", "644", filtered_path, CERT_PATH), sudo: true)
    add_error("Failed to remove compromised roots from #{CERT_PATH}") unless status.zero?
  ensure
    @system.rm_rf(filtered_path) if filtered_path
  end

  def complete?
    super
    add_error("Compromised eMudhra roots remain in #{CERT_PATH}") if affected?
    @errors.empty?
  end

  private

  def affected?
    @system.file_exist?(CERT_PATH) && @system.read_file(CERT_PATH).match?(ROOT_HEADING_PATTERN)
  end

  def filtered_bundle
    skipping = false
    @system.read_file(CERT_PATH).lines.filter_map do |line|
      skipping = line.match?(ROOT_HEADING_PATTERN) if line.start_with?("=== ")
      retained = line unless skipping
      skipping = false if skipping && line.start_with?("-----END CERTIFICATE-----")
      retained
    end.join
  end
end
