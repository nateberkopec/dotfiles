class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  DESCRIPTION = "Configures SSH to sign with the 1Password SSH agent.".freeze

  macos_only

  SSH_CONFIG_PATH = File.expand_path("~/.ssh/config")
  OP_AGENT_PATH = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  DEFAULT_AGENT = %(Host *\n  IdentityAgent "#{OP_AGENT_PATH}"\n)
  HOMELAB_KEY = "~/.ssh/sfactory_ed25519"
  LEGACY_BLOCK = <<~SSH
    Host sfactory server-1 server-2
      IdentityFile #{HOMELAB_KEY}
      IdentitiesOnly yes
      IdentityAgent none
  SSH
  AGENT_BLOCK = <<~SSH
    Host sfactory server-1 server-2
      IdentityFile #{HOMELAB_KEY}.pub
      IdentitiesOnly yes
      IdentityAgent "#{OP_AGENT_PATH}"
  SSH

  def self.display_name
    "Setup SSH Keys"
  end

  def should_run?
    !unattended? && !complete?
  end

  def run
    exists = @system.file_exist?(SSH_CONFIG_PATH)
    original = exists ? @system.read_file(SSH_CONFIG_PATH) : ""
    content = original.dup
    if content.include?(LEGACY_BLOCK)
      unless homelab_agent_signs?
        add_warning(title: "Homelab SSH config unchanged", message: import_notice)
        return
      end
      content.gsub!(LEGACY_BLOCK, AGENT_BLOCK)
    end
    unless content.include?(DEFAULT_AGENT)
      content << "\n\n" unless content.empty?
      content << DEFAULT_AGENT
      add_notice(title: "1Password SSH Agent Setup", message: "Enable the SSH agent in 1Password Settings → Developer.")
    end
    return if content == original
    @system.mkdir_p(File.dirname(SSH_CONFIG_PATH))
    @system.write_file(SSH_CONFIG_PATH, content)
    @system.chmod(0o600, SSH_CONFIG_PATH) unless exists
  end

  def complete?
    super
    return true if unattended?
    unless @system.file_exist?(SSH_CONFIG_PATH)
      add_error("SSH config file does not exist at #{SSH_CONFIG_PATH}")
      return false
    end
    content = @system.read_file(SSH_CONFIG_PATH)
    add_error("SSH config missing default 1Password agent") unless content.include?(DEFAULT_AGENT)
    add_error("Homelab SSH still uses a private key file", fix: import_notice) if content.include?(LEGACY_BLOCK)
    @errors.empty?
  end

  private

  def unattended?
    Dotfiles::Step::Sudoable.ci_or_noninteractive?
  end

  def import_notice
    "Import #{HOMELAB_KEY} into 1Password, keep its matching .pub file and allow the SSH agent to sign, then rerun setup."
  end

  def homelab_agent_signs?
    command_succeeds?(env_command({"SSH_AUTH_SOCK" => expand_path_with_home(OP_AGENT_PATH)},
      "ssh-add", "-T", expand_path_with_home("#{HOMELAB_KEY}.pub")))
  end
end
