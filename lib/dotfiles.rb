#!/usr/bin/env ruby

require_relative "dotfiles/loader"

Dotfiles::Loader.load!

class Dotfiles
  @log_file = nil
  @log_io = nil

  def self.log_file=(path)
    return if @log_file == path

    @log_io&.close
    @log_io = nil
    @log_file = path
  end

  def self.log_file
    @log_file
  end

  def self.debug(message)
    formatted = format_debug_message(message)
    write_log(formatted)
    puts formatted if ENV["DEBUG"] == "true"
  end

  def self.write_log(formatted)
    return unless @log_file

    @log_io ||= begin
      io = File.open(@log_file, "a")
      io.sync = true
      io
    end
    @log_io.puts(formatted)
  end
  private_class_method :write_log

  at_exit { @log_io&.close }

  def self.format_debug_message(message)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    lines = encode_utf8(message.to_s).lines(chomp: true)
    lines = [""] if lines.empty?
    lines.map { |line| "[#{timestamp}] #{line}" }.join("\n")
  end
  private_class_method :format_debug_message

  def self.encode_utf8(value)
    source_encoding = (value.encoding == Encoding::ASCII_8BIT) ? Encoding::UTF_8 : value.encoding
    value.encode(Encoding::UTF_8, source_encoding, invalid: :replace, undef: :replace, replace: "�")
  rescue EncodingError
    value.dup.force_encoding(Encoding::UTF_8).scrub
  end

  def self.debug_benchmark(label, &block)
    start = Time.now
    result = block.call
    elapsed = ((Time.now - start) * 1000).round(2)
    debug "#{label} took #{elapsed}ms"
    result
  end

  def self.command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def self.determine_dotfiles_dir
    env_dir = ENV["DOTFILES_DIR"].to_s.strip
    if !env_dir.empty?
      expanded = File.expand_path(env_dir)
      return expanded if Dir.exist?(expanded)
    end

    cwd = Dir.pwd
    return cwd if File.exist?(File.join(cwd, "config", "config.yml"))

    # In CI, the dotfiles are in the current working directory
    # In normal usage, they're in ~/.dotfiles
    ENV["CI"] ? cwd : File.expand_path("~/.dotfiles")
  end
end
