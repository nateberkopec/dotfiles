# frozen_string_literal: true

require "optparse"
require "pty"
require "timeout"

class DotagentsDriver
  CLIENTS = %w[claude factory codex cursor opencode gemini github ampcode].freeze

  def initialize(home:, clients:, dotagents_command:)
    @home = home
    @clients = clients
    @dotagents_command = dotagents_command
  end

  def run
    PTY.spawn({"HOME" => @home}, @dotagents_command) do |reader, writer, pid|
      @reader = reader
      @writer = writer
      choose_workspace
      choose_clients
      apply_changes
      exit_overview
      Process.wait(pid)
      status = $CHILD_STATUS.exitstatus
      raise "dotagents failed with status #{status}" unless status == 0
    end
  rescue PTY::ChildExited => e
    raise "dotagents failed with status #{e.status.exitstatus}" unless e.status.exitstatus == 0
  end

  private

  def choose_workspace
    wait_for("Choose a workspace")
    send_keys("\r")
  end

  def choose_clients
    wait_for("Select clients to manage")
    send_keys("a")
    CLIENTS.each_with_index do |client, index|
      send_keys(" ") if @clients.include?(client)
      send_keys("\e[B") unless index == CLIENTS.length - 1
    end
    send_keys("\r")
  end

  def apply_changes
    menu = wait_for("Choose an action")
    return unless menu.include?("Apply") || menu.include?("Resolve")

    send_keys("\r")
    loop do
      output = wait_for("overwrite conflicts", "Apply changes now?", "Choose an action", seconds: 60)
      if output.include?("overwrite conflicts")
        send_keys("\r")
        next
      end
      return if output.include?("Choose an action")

      send_keys("\r")
      wait_for("Choose an action", seconds: 60)
      return
    end
  end

  def exit_overview
    send_keys("\e[B\e[B\e[B\r")
  end

  def wait_for(*needles, seconds: 15)
    buffer = +""
    Timeout.timeout(seconds) do
      loop do
        return buffer if needles.any? { |needle| buffer.include?(needle) }

        ready = IO.select([@reader], nil, nil, 0.1)
        next unless ready

        chunk = @reader.read_nonblock(4096)
        $stdout.write(chunk)
        $stdout.flush
        buffer << chunk
      rescue IO::WaitReadable, Errno::EIO
        next
      rescue EOFError
        return buffer
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for: #{needles.join(", ")}"
  end

  def send_keys(keys)
    @writer.write(keys)
    @writer.flush
  end
end

options = {clients: []}
OptionParser.new do |parser|
  parser.on("--home PATH") { |value| options[:home] = value }
  parser.on("--clients LIST") { |value| options[:clients] = value.split(",") }
  parser.on("--dotagents-command COMMAND") { |value| options[:dotagents_command] = value }
end.parse!

DotagentsDriver.new(
  home: options.fetch(:home),
  clients: options.fetch(:clients),
  dotagents_command: options.fetch(:dotagents_command)
).run
