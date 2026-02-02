class Dotfiles::Step::InstallDebianClaudeCodeStep < Dotfiles::Step
  include Dotfiles::Step::DebianNonAptHelper

  debian_only

  CLAUDE_CODE_INSTALL_URL = "https://claude.ai/install.sh".freeze

  def self.display_name
    "Claude Code"
  end

  def self.depends_on
    [Dotfiles::Step::InstallDebianPackagesStep]
  end

  def should_run?
    configured? && !installed?
  end

  def run
    install_claude_code if configured?
  end

  def complete?
    super
    return true unless configured?
    return true if installed?
    add_error("Non-APT package not installed: claude-code")
    false
  end

  private

  def configured?
    @config.debian_non_apt_packages.include?("claude-code")
  end

  def installed?
    package_installed?("claude-code", command: "claude")
  end

  def install_claude_code
    return if installed?
    output, status = execute("curl -fsSL #{CLAUDE_CODE_INSTALL_URL} | bash")
    add_error("Claude Code install failed (status #{status}): #{output}") unless status == 0
  end
end
