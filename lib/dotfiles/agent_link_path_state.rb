module Dotfiles::AgentLinkPathState
  private

  def path_exists?(path)
    !path_kind(path).nil?
  end

  def path_kind(path)
    return :symlink if @system.symlink?(path)
    return :dir if @system.dir_exist?(path)
    return :file if @system.file_exist?(path)

    nil
  end
end
