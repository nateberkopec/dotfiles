path = ENV.fetch("PATH")
local_bin = File.join(ENV.fetch("HOME"), ".local/bin")
ENV["PATH"] = "#{path}#{File::PATH_SEPARATOR}#{local_bin}" unless path.split(File::PATH_SEPARATOR).include?(local_bin)
