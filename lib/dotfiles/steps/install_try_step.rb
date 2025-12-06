class Dotfiles::Step::InstallTryStep < Dotfiles::Step
  def should_run?
    !@system.file_exist?(try_path)
  end

  def run
    debug "Installing try.rb..."
    @system.mkdir_p(File.dirname(try_path))
    execute("curl -sL https://raw.githubusercontent.com/tobi/try/refs/heads/main/try.rb -o #{try_path}")
    @system.chmod(0o755, try_path)
  end

  def complete?
    super
    return true if @system.file_exist?(try_path)

    add_error("try.rb is not installed")
    false
  end

  private

  def try_path
    File.join(@home, "Documents/Code.nosync/upstream/try/try.rb")
  end
end
