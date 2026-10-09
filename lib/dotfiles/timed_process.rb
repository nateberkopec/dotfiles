class Dotfiles
  class TimedProcess
    TIMED_OUT_STATUS = 124
    KILL_GRACE_SECONDS = 5

    def initialize(argv, timeout:, stream:)
      @argv, @timeout, @stream = argv, timeout, stream
      @output = +""
    end

    def run
      reader, writer = IO.pipe
      pid = Process.spawn(*@argv, in: File::NULL, out: writer, err: writer, pgroup: true)
      writer.close
      collector = Thread.new { collect(reader) }
      waiter = Thread.new { Process.wait2(pid).last }
      status = waiter.join(@timeout) ? waiter.value.exitstatus : terminate(pid, waiter)
      collector.join
      [@output, status]
    ensure
      reader&.close
    end

    private

    def collect(reader)
      reader.each_line do |line|
        $stdout.write(line) if @stream
        @output << line
      end
    end

    def terminate(pid, waiter)
      signal_group("TERM", pid)
      signal_group("KILL", pid) unless waiter.join(KILL_GRACE_SECONDS)
      waiter.join
      @output << "\nTimed out after #{@timeout}s\n"
      TIMED_OUT_STATUS
    end

    def signal_group(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH
      nil
    end
  end
end
