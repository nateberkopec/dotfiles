#!/usr/bin/env ruby

require "timeout"

class ServeUrlCheck
  URL_PATTERN = %r{https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]|[A-Za-z0-9.-]+\.local)(?::\d+)?(?:/\S*)?}
  DEFAULT_TIMEOUT_SECONDS = 10.0
  SHUTDOWN_TIMEOUT_SECONDS = 2.0

  def initialize(target_dir)
    @target_dir = target_dir
    @output = +""
  end

  def run
    run_serve_task

    if last_output_lines.match?(URL_PATTERN)
      puts "serve task logged a URL in the last 10 lines of output."
    else
      warn "serve task did not log a URL in the last 10 lines of output."
      warn "Expected a URL like http://localhost:4000 or https://localhost:4000."
      warn "Last 10 output lines:"
      warn last_output_lines
      exit 1
    end
  end

  private

  attr_reader :target_dir, :output

  def run_serve_task
    reader, writer = IO.pipe
    pid = Process.spawn("mise", "run", "serve", chdir: target_dir, out: writer, err: writer, pgroup: true)
    writer.close

    reader_thread = Thread.new { read_output(reader) }
    wait_for_serve(pid)
    reader.close unless reader.closed?
    reader_thread.join(SHUTDOWN_TIMEOUT_SECONDS)
  end

  def read_output(reader)
    loop do
      output << reader.readpartial(4096)
    end
  rescue IOError
  end

  def wait_for_serve(pid)
    Timeout.timeout(timeout_seconds) { Process.wait(pid) }
  rescue Timeout::Error
    stop_process_group(pid)
  end

  def stop_process_group(pid)
    Process.kill("TERM", -pid)
    wait_for_shutdown(pid)
  rescue Errno::ESRCH, Errno::ECHILD
  end

  def wait_for_shutdown(pid)
    Timeout.timeout(SHUTDOWN_TIMEOUT_SECONDS) { Process.wait(pid) }
  rescue Timeout::Error
    Process.kill("KILL", -pid)
    Process.wait(pid)
  end

  def last_output_lines
    output.lines.last(10).join
  end

  def timeout_seconds
    configured_timeout = ENV.fetch("SERVE_URL_CHECK_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS).to_f
    configured_timeout.positive? ? configured_timeout : DEFAULT_TIMEOUT_SECONDS
  end
end

ServeUrlCheck.new(ARGV.fetch(0)).run
