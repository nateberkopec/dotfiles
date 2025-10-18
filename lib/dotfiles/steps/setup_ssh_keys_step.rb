class Dotfiles::Step::SetupSSHKeysStep < Dotfiles::Step
  SSH_CONFIG_PATH = File.expand_path("~/.ssh/config")
  OP_AGENT_PATH = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

  def self.display_name
    "Setup SSH Keys"
  end

  attr_reader :needs_manual_setup

  def initialize(**kwargs)
    super
    @needs_manual_setup = false
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

    FileUtils.mkdir_p(File.dirname(SSH_CONFIG_PATH))

    if File.exist?(SSH_CONFIG_PATH)
      config_content = File.read(SSH_CONFIG_PATH)
      unless config_content.include?("IdentityAgent")
        File.open(SSH_CONFIG_PATH, "a") do |f|
          f.puts
          f.puts "Host *"
          f.puts "  IdentityAgent \"#{OP_AGENT_PATH}\""
        end
        debug "Added 1Password SSH agent to #{SSH_CONFIG_PATH}"
        @needs_manual_setup = true
      end
    else
      File.write(SSH_CONFIG_PATH, <<~CONFIG)
        Host *
          IdentityAgent "#{OP_AGENT_PATH}"
      CONFIG
      File.chmod(0o600, SSH_CONFIG_PATH)
      debug "Created #{SSH_CONFIG_PATH} with 1Password SSH agent"
      @needs_manual_setup = true
    end
  end

  def complete?
    return true if ci_or_noninteractive?
    return false unless File.exist?(SSH_CONFIG_PATH)

    config_content = File.read(SSH_CONFIG_PATH)
    config_content.include?("IdentityAgent") && config_content.include?("1password")
  end
end
