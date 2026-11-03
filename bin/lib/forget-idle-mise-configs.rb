#!/usr/bin/env ruby

IDLE_SECONDS = 14 * 24 * 60 * 60

def git_dir(config)
  dir = File.dirname(config)
  until dir == "/"
    dot_git = File.join(dir, ".git")
    return dot_git if File.directory?(dot_git)
    return File.expand_path(File.read(dot_git)[/\Agitdir: (.+)$/, 1], dir) if File.file?(dot_git)
    dir = File.dirname(dir)
  end
end

def active?(config)
  dir = git_dir(config)
  return false unless dir

  marker = %w[index HEAD].map { |name| File.join(dir, name) }.find { |path| File.exist?(path) }
  marker && Time.now - File.mtime(marker) < IDLE_SECONDS
end

state_dir = ENV["MISE_STATE_DIR"] || File.join(ENV["XDG_STATE_HOME"] || File.join(Dir.home, ".local/state"), "mise")
links = Dir.glob(File.join(state_dir, "tracked-configs", "*")).select { |path| File.symlink?(path) }
idle = links.reject { |link| active?(File.readlink(link)) }
idle.each { |link| File.delete(link) }
puts "Forgot #{idle.size} idle mise configs; #{links.size - idle.size} remain"
