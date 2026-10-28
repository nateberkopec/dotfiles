class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  DESCRIPTION = "Configures SSH to use the 1Password SSH agent, except for hosts that use a key outside it.".freeze

  macos_only

  SSH_CONFIG_PATH = File.expand_path("~/.ssh/config")
  OP_AGENT_PATH = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  def self.display_name
    "Setup SSH Keys"
  end

  def should_run?
    !unattended? && !complete?
  end

  def run
    debug "Setting up 1Password SSH agent..."
    @system.mkdir_p(File.dirname(SSH_CONFIG_PATH))
    agent_configured = configure_ssh_agent
    add_host_blocks
    show_setup_notice if agent_configured
  end

  def complete?
    super
    return true if unattended?
    unless @system.file_exist?(SSH_CONFIG_PATH)
      add_error("SSH config file does not exist at #{SSH_CONFIG_PATH}")
      return false
    end
    content = @system.read_file(SSH_CONFIG_PATH)
    validate_ssh_config(content)
    missing_host_blocks(content).each { |block| add_error("SSH config missing #{block.lines.first.strip}") }
    @errors.empty?
  end

  private

  def unattended?
    Dotfiles::Step::Sudoable.ci_or_noninteractive?
  end

  def configure_ssh_agent
    @system.file_exist?(SSH_CONFIG_PATH) ? append_agent_config : create_ssh_config
  end

  def append_agent_config
    return false if @system.read_file(SSH_CONFIG_PATH).include?("IdentityAgent")
    @system.write_file(SSH_CONFIG_PATH, @system.read_file(SSH_CONFIG_PATH) + agent_config_block)
    debug "Added 1Password SSH agent to #{SSH_CONFIG_PATH}"
    true
  end

  def create_ssh_config
    @system.write_file(SSH_CONFIG_PATH, "Host *\n  IdentityAgent \"#{OP_AGENT_PATH}\"\n")
    @system.chmod(0o600, SSH_CONFIG_PATH)
    debug "Created #{SSH_CONFIG_PATH} with 1Password SSH agent"
    true
  end

  def agent_config_block
    "\n\nHost *\n  IdentityAgent \"#{OP_AGENT_PATH}\"\n"
  end

  def add_host_blocks
    content = @system.read_file(SSH_CONFIG_PATH)
    missing = missing_host_blocks(content)
    return if missing.empty?
    agent_block = content.index(/^Host \*$/) || content.length
    @system.write_file(SSH_CONFIG_PATH, content.dup.insert(agent_block, missing.join))
    debug "Added #{missing.length} host blocks to #{SSH_CONFIG_PATH}"
  end

  def missing_host_blocks(content)
    host_blocks.reject { |block| content.include?(block) }
  end

  def host_blocks
    @config.fetch("ssh_agentless_hosts", []).map do |entry|
      "Host #{entry.fetch("hosts").join(" ")}\n  IdentityFile #{entry.fetch("identity_file")}\n  IdentitiesOnly yes\n  IdentityAgent none\n\n"
    end
  end

  def show_setup_notice
    add_notice(title: "ℹ️  1Password SSH Agent Setup Required", message: "To complete SSH setup:\n1. Open 1Password app\n2. Go to Settings → Developer\n3. Enable 'Use the SSH agent'")
  end

  def validate_ssh_config(content)
    add_error("SSH config missing IdentityAgent setting") unless content.include?("IdentityAgent")
    add_error("SSH config missing 1Password agent reference") unless content.include?("1password")
  end
end
