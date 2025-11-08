class Dotfiles::Step::SetFontSmoothingStep < Dotfiles::Step
  include Dotfiles::Step::Defaultable

  def run
    debug "Disabling font smoothing for better text rendering..."
    execute("defaults -currentHost write -g AppleFontSmoothing -int 0")
  end

  def complete?
    defaults_read_equals?(build_read_command("NSGlobalDomain", "AppleFontSmoothing", current_host: true), "0")
  end

  private

  def build_read_command(domain, key, current_host: false)
    domain_flag = domain_flag_for(domain)
    host_flag = current_host ? "-currentHost " : ""
    "defaults #{host_flag}read #{domain_flag} #{key}"
  end
end
