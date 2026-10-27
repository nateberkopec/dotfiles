class Dotfiles
  module StepProgress
    MUTEX = Mutex.new

    module_function

    def track(name)
      say "▸ #{name}"
      start = Time.now
      result = yield
      say "✓ #{name} (#{duration(Time.now - start)})"
      result
    rescue => e
      say "✗ #{name}: #{e.message}"
      raise
    end

    def duration(seconds)
      (seconds < 1) ? "#{(seconds * 1000).round}ms" : "#{seconds.round(1)}s"
    end

    def say(line)
      MUTEX.synchronize { $stdout.puts "  #{line}" }
    end
  end
end
