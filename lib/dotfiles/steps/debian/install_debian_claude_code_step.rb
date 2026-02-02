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

  def install
    return if installed?
    output, status = execute("curl -fsSL #{CLAUDE_CODE_INSTALL_URL} | bash")
    add_error("Claude Code install failed (status #{status}): #{output}") unless status == 0
  end
end
