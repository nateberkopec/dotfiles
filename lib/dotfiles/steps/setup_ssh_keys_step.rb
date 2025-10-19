class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  SSH_CONFIG_PATH = File.expand_path("~/.ssh/config")
  OP_AGENT_PATH = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  def self.display_name
    "Setup SSH Keys"
  end

  def should_run?
    if ci_or_noninteractive?
      debug "Skipping 1Password SSH agent setup in CI/non-interactive environment"
      return false
    end
    !complete?
  end

  def run
    debug "Setting up 1Password SSH agent..."

    @system.mkdir_p(File.dirname(SSH_CONFIG_PATH))

    needs_setup = false
    if @system.file_exist?(SSH_CONFIG_PATH)
      config_content = @system.read_file(SSH_CONFIG_PATH)
      unless config_content.include?("IdentityAgent")
        current_content = @system.read_file(SSH_CONFIG_PATH)
        new_content = current_content + "\n\nHost *\n  IdentityAgent \"#{OP_AGENT_PATH}\"\n"
        @system.write_file(SSH_CONFIG_PATH, new_content)
        debug "Added 1Password SSH agent to #{SSH_CONFIG_PATH}"
        needs_setup = true
      end
    else
      @system.write_file(SSH_CONFIG_PATH, <<~CONFIG)
        Host *
          IdentityAgent "#{OP_AGENT_PATH}"
      CONFIG
      @system.chmod(0o600, SSH_CONFIG_PATH)
      debug "Created #{SSH_CONFIG_PATH} with 1Password SSH agent"
      needs_setup = true
    end

    if needs_setup
      add_notice(
        title: "ℹ️  1Password SSH Agent Setup Required",
        message: "To complete SSH setup:\n1. Open 1Password app\n2. Go to Settings → Developer\n3. Enable 'Use the SSH agent'"
      )
    end
  end

  def complete?
    return true if ci_or_noninteractive?
    return false unless @system.file_exist?(SSH_CONFIG_PATH)

    config_content = @system.read_file(SSH_CONFIG_PATH)
    config_content.include?("IdentityAgent") && config_content.include?("1password")
  end
end
