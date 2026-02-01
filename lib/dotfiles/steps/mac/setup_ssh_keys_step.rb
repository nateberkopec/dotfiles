class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  prepend Dotfiles::Step::Sudoable

  macos_only

  SSH_CONFIG_PATH = File.expand_path("~/.ssh/config")
  OP_AGENT_PATH = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  def self.display_name
    "Setup SSH Keys"
  end

  def should_run?
    !complete?
  end

  def run
    debug "Setting up 1Password SSH agent..."
    @system.mkdir_p(File.dirname(SSH_CONFIG_PATH))
    show_setup_notice if configure_ssh_agent
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

  def show_setup_notice
    add_notice(title: "ℹ️  1Password SSH Agent Setup Required", message: "To complete SSH setup:\n1. Open 1Password app\n2. Go to Settings → Developer\n3. Enable 'Use the SSH agent'")
  end

  def complete?
    super
    unless @system.file_exist?(SSH_CONFIG_PATH)
      add_error("SSH config file does not exist at #{SSH_CONFIG_PATH}")
      return false
    end
    validate_ssh_config(@system.read_file(SSH_CONFIG_PATH))
    @errors.empty?
  end

  def validate_ssh_config(content)
    add_error("SSH config missing IdentityAgent setting") unless content.include?("IdentityAgent")
    add_error("SSH config missing 1Password agent reference") unless content.include?("1password")
  end
end
