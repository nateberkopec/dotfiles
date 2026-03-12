class Dotfiles::Step::PatchPiAutoRetryStep < Dotfiles::Step
  RETRY_MATCHER = "server error|internal error"
  PATCHED_RETRY_MATCHER = "server(?: |_)?error|internal(?: |_)?error"

  def self.display_name
    "Patch Pi Auto Retry"
  end

  def self.depends_on
    [Dotfiles::Step::InstallMiseToolsStep]
  end

  def should_run?
    return false unless patch_target

    !complete?
  end

  def run
    return unless patch_target

    debug "Patching pi retry matcher in #{collapse_path_to_home(patch_target)}..."
    @system.write_file(patch_target, patched_content)
  end

  def complete?
    super
    return true unless patch_target

    retry_matcher_patched?
  end

  private

  def patch_target
    return @patch_target if defined?(@patch_target)

    pi_path = pi_binary_path
    return @patch_target = nil if pi_path.nil? || pi_path.empty?

    candidate = File.expand_path("../lib/node_modules/@mariozechner/pi-coding-agent/dist/core/agent-session.js", File.dirname(pi_path))
    @patch_target = @system.file_exist?(candidate) ? candidate : nil
  end

  def pi_binary_path
    output, status = execute("command -v pi 2>/dev/null")
    return nil unless status == 0

    output.strip
  end

  def retry_matcher_patched?
    @system.read_file(patch_target).include?(PATCHED_RETRY_MATCHER)
  end

  def patched_content
    content = @system.read_file(patch_target)
    return content if content.include?(PATCHED_RETRY_MATCHER)

    unless content.include?(RETRY_MATCHER)
      raise "Could not find pi retry matcher in #{patch_target}"
    end

    content.sub(RETRY_MATCHER, PATCHED_RETRY_MATCHER)
  end
end
