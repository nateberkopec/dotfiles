class Dotfiles::Step::InstallDebianClaudeCodeStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptStep

  CLAUDE_CODE_INSTALL_URL = "https://claude.ai/install.sh".freeze

  def self.display_name
    "Claude Code"
  end

  private

  def package_name
    "claude-code"
  end

  def command_name
    "claude"
  end

  def install_script_url
    CLAUDE_CODE_INSTALL_URL
  end

  def install_shell
    "bash"
  end

  def install_error_label
    "Claude Code"
  end
end
