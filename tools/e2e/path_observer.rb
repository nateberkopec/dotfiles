if ENV["DOTF_PATH_DIAGNOSTIC"] == "1"
  home = ENV.fetch("HOME", "")
  project = File.join(home, ".dotfiles")
  classify_path = lambda do |value|
    raise ArgumentError unless value.is_a?(String) && value.bytesize <= 16_384
    entries = value.split(File::PATH_SEPARATOR)
    {count: entries.length, localbin: entries.include?(File.join(home, ".local/bin")), projectbin: entries.include?(File.join(project, "bin")), shims: entries.include?(File.join(home, ".local/share/mise/shims"))}
  end
  decode = lambda do |raw|
    raise ArgumentError unless raw && raw.bytesize <= 16_384 && raw.match?(/\A[A-Za-z0-9+\/]+\z/)
    require "zlib"
    bytes = (raw + "=" * ((4 - raw.length % 4) % 4)).unpack1("m0")
    data = +"".b
    inflater = Zlib::Inflate.new
    begin
      inflater.inflate(bytes) do |chunk|
        raise ArgumentError if data.bytesize + chunk.bytesize > 65_536
        data << chunk
      end
      raise ArgumentError unless inflater.finished? && inflater.total_in == bytes.bytesize
    ensure
      inflater.close
    end
    offset = entries = 0
    take = lambda do |count|
      raise ArgumentError if count < 0 || offset + count > data.bytesize
      value = data.byteslice(offset, count)
      offset += count
      value
    end
    parse = lambda do |depth, mode|
      entries += 1
      raise ArgumentError if depth > 8 || entries > 256
      tag = take.call(1).getbyte(0)
      case tag
      when 0..127 then tag
      when 192 then nil
      when 160..191, 217..219
        length = if tag < 192
          tag - 160
        else
          take.call(2**(tag - 217)).unpack1({217 => "C", 218 => "n", 219 => "N"}.fetch(tag))
        end
        value = take.call(length)
        case mode
        when :key
          raise ArgumentError if value.bytesize > 64
          value
        when :path_item
          raise ArgumentError if value.bytesize > 4096
          value
        when :home
          raise ArgumentError if value.bytesize > 4096
          {present: true, matches_current: value == home}
        when :env_path then classify_path.call(value)
        end
      when 204..207 then take.call(2**(tag - 204)).unpack1({204 => "C", 205 => "n", 206 => "N", 207 => "Q>"}.fetch(tag))
      when 144..159, 220, 221
        if tag < 160
          count = tag - 144
        else
          width, format = {220 => [2, "n"], 221 => [4, "N"]}.fetch(tag)
          count = take.call(width).unpack1(format)
        end
        raise ArgumentError if count > 256 || ![:path, :skip].include?(mode)
        values = Array.new(count) { parse.call(depth + 1, (mode == :path) ? :path_item : :skip) }
        (mode == :path) ? values : nil
      when 128..143, 222, 223
        if tag < 144
          count = tag - 128
        else
          width, format = {222 => [2, "n"], 223 => [4, "N"]}.fetch(tag)
          count = take.call(width).unpack1(format)
        end
        raise ArgumentError if count > 128 || ![:root, :env, :skip].include?(mode)
        pairs = {}
        seen = []
        count.times do
          key = parse.call(depth + 1, (mode == :skip) ? :skip : :key)
          raise ArgumentError if mode != :skip && (!key.is_a?(String) || seen.include?(key))
          seen << key unless mode == :skip
          child = if mode == :root
            {"v" => :version, "path" => :path, "old" => :env, "new" => :env}.fetch(key, :skip)
          elsif mode == :env
            {"HOME" => :home, "PATH" => :env_path}.fetch(key, :skip)
          else
            :skip
          end
          value = parse.call(depth + 1, child)
          pairs[key] = value unless child == :skip
        end
        (mode == :skip) ? nil : pairs
      else raise ArgumentError
      end
    end
    result = parse.call(0, :root)
    raise ArgumentError unless offset == data.bytesize && result.is_a?(Hash) && [1, 2].include?(result.fetch("v", 1)) && result.fetch("path", []).is_a?(Array) && result.fetch("path", []).all? { |path| path.is_a?(String) }
    %w[old new].each do |key|
      raise ArgumentError if result.key?(key) && !result[key].is_a?(Hash)
      result.fetch(key, {}).each do |name, value|
        raise ArgumentError unless value.nil? || value.is_a?(Hash)
      end
    end
    result
  rescue LoadError, StandardError
    nil
  end
  signature = lambda do
    value = ENV.fetch("PATH", "")
    raise ArgumentError if value.bytesize > 16_384
    paths = value.split(File::PATH_SEPARATOR)
    [paths.length, paths.include?(File.join(ENV.fetch("HOME", ""), ".local/bin")), paths.first(64).any? { |path| path.bytesize <= 4096 && File.executable?(File.join(path, "mise")) }]
  rescue
    [-1, "unavailable", "unavailable"]
  end
  mutations = calls = records = 0
  report = lambda do |stage, extra = {}|
    next if records >= 6
    records += 1
    home = ENV.fetch("HOME", "")
    project = File.join(home, ".dotfiles")
    raise ArgumentError if home.bytesize > 4096
    bounded = %w[HOME PATH __MISE_ORIG_PATH BUNDLER_ORIG_PATH RUBYOPT __MISE_DIFF BASH_ENV MISE_NO_ENV MISE_SAFE MISE_SAFE_MODE MISE_ENV_CACHE]
    raise ArgumentError if bounded.sum { |key| ENV.fetch(key, "").bytesize } + $PROGRAM_NAME.bytesize + 5120 > 65_536
    %w[PATH __MISE_ORIG_PATH BUNDLER_ORIG_PATH].each { |key| raise ArgumentError if ENV.fetch(key, "").bytesize > 16_384 }
    raise ArgumentError if ENV.fetch("BASH_ENV", "").bytesize > 4096
    paths = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
    raise ArgumentError if paths.any? { |path| path.bytesize > 4096 }
    diff = decode.call(ENV["__MISE_DIFF"])
    diff_paths = diff ? diff.fetch("path", []) : []
    localbin = File.join(home, ".local/bin")
    bash_env = case ENV["BASH_ENV"]
    when nil then "unset"
    when "" then "empty"
    when File.join(home, ".config/bash/safety.bash") then "managed_safety"
    else "other"
    end
    script = $PROGRAM_NAME
    raise ArgumentError if script.bytesize > 4096
    script_path = File.expand_path(script)
    ruby_bin = File.join(home, ".local/share/mise/installs/ruby/4.0.7/bin")
    script_class = if script == "-e"
      "inline"
    elsif script_path == File.join(ruby_bin, "bundle")
      "managed_bundle"
    elsif script_path == File.join(ruby_bin, "bundler")
      "managed_bundler"
    elsif script_path.start_with?(File.join(project, ""))
      "project"
    else
      "other"
    end
    script_known = %w[managed_bundle managed_bundler].include?(script_class)
    shebang = "unavailable"
    symlink = "unavailable"
    symlink_class = "unavailable"
    if script_known
      symlink = File.symlink?(script_path)
      if symlink
        target = File.readlink(script_path)
        raise ArgumentError if target.bytesize > 4096
        symlink_class = (File.expand_path(target, File.dirname(script_path)) == File.join(ruby_bin, "bundle")) ? "managed_bundle" : "other"
      else
        symlink_class = "none"
      end
      header = symlink ? "" : File.open(script_path, "rb") { |file| file.read(1024).to_s }
      shebang = if symlink
        "unavailable"
      elsif header.start_with?("#!/bin/sh\n")
        "bin_sh"
      elsif header.start_with?("#!/usr/bin/env ruby\n")
        "env_ruby"
      elsif header.start_with?("#!#{ruby_bin}/ruby\n")
        "managed_ruby"
      else
        "other"
      end
    end
    rubyopt = ENV.fetch("RUBYOPT", "")
    raise ArgumentError if rubyopt.bytesize > 4096
    rubyopt_complete = !rubyopt.match?(/["'\\]/) && !rubyopt.include?("--require")
    requires = rubyopt_complete ? rubyopt.scan(/(?:\A|\s)-r\s*([^\s]+)/).flatten : []
    own_observer = File.join(project, "tools/e2e/path_observer.rb")
    other_requires = requires.reject { |value| value == own_observer }
    fields = {stage: stage, pid: Process.pid, script: script_class, script_symlink: symlink, symlink_target: symlink_class, shebang: shebang, rubyopt_complete: rubyopt_complete, rubyopt_other_require_count: rubyopt_complete ? other_requires.length : "unavailable", rubyopt_bundler_setup: rubyopt_complete ? other_requires.any? { |value| %w[bundler/setup bundler/setup.rb].include?(value) } : "unavailable", path_count: paths.length, path_scan_complete: paths.length <= 64, localbin_on_path: paths.include?(localbin), mise_file: File.file?(File.join(localbin, "mise")), mise_executable: File.executable?(File.join(localbin, "mise")), mise_on_scanned_path: signature.call.last, original_mise_localbin: ENV.fetch("__MISE_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin), original_bundle_localbin: ENV.fetch("BUNDLER_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin), diff_ok: !diff.nil?, diff_version: diff ? diff.fetch("v", 1) : "unavailable", diff_path_count: diff_paths.length, diff_localbin: diff_paths.include?(localbin), diff_projectbin: diff_paths.include?(File.join(project, "bin")), cwd_project: Dir.pwd == project, bundler_loaded: Object.const_defined?(:Bundler, false) && !Object.autoload?(:Bundler), bash_env: bash_env, mutations: mutations, mutation_scan_complete: mutations <= 3}
    %w[old new].each do |side|
      values = diff ? diff.fetch(side, {}) : {}
      fields["#{side}_home"] = if !values.key?("HOME")
        "absent"
      elsif !values["HOME"]
        "unset"
      elsif values["HOME"][:matches_current]
        "current"
      else
        "different"
      end
      fields["#{side}_path"] = if !values.key?("PATH")
        "absent"
      elsif values["PATH"]
        "classified"
      else
        "unset"
      end
      fields["#{side}_path_count"] = values.fetch("PATH", nil) ? values["PATH"][:count] : "unavailable"
      fields["#{side}_path_localbin"] = values.fetch("PATH", nil) ? values["PATH"][:localbin] : "unavailable"
      fields["#{side}_path_projectbin"] = values.fetch("PATH", nil) ? values["PATH"][:projectbin] : "unavailable"
    end
    %w[MISE_NO_ENV MISE_SAFE MISE_SAFE_MODE MISE_ENV_CACHE].each do |key|
      value = ENV[key]
      raise ArgumentError if value && value.bytesize > 64
      fields[key.downcase] = case value
      when nil then "unset"
      when "1", "true" then "true"
      when "0", "false" then "false"
      else "other"
      end
    end
    %w[__MISE_ENV_CACHE_KEY MISE_CONFIG_DIR MISE_CONFIG_FILE MISE_GLOBAL_CONFIG_FILE BASH_ENV RUBYOPT __MISE_DIFF].each { |key| fields["present_#{key}"] = ENV.key?(key) }
    line = "e2e-context-diagnostic #{fields.merge(extra).map { |key, value| "#{key}=#{value}" }.join(" ")}"
    raise ArgumentError if line.bytesize > 2048
    warn line
  rescue
    warn "e2e-context-diagnostic stage=observer_error diagnostic_ok=false"
  end
  stage = ENV["DOTF_PATH_DIAGNOSTIC_STAGE"]
  if %w[before_bootstrap after_bootstrap before_dependencies].include?(stage)
    report.call(stage)
  else
    report.call("ruby_entry")
    pending = {}
    trace = TracePoint.new(:call, :c_call, :c_return) do |event|
      if event.self.equal?(ENV) && %i[[]= store replace update merge! delete clear shift delete_if reject! select! filter! keep_if].include?(event.method_id)
        key = Thread.current.object_id
        if event.event == :c_call
          (pending[key] ||= []).push(signature.call)
        elsif event.event == :c_return
          before = pending[key]&.pop
          pending.delete(key) if pending[key] && pending[key].empty?
          if before && before != signature.call
            mutations += 1
            source = if event.path.include?("/bundler-")
              "bundler"
            elsif event.path.end_with?("/rubygems_plugin.rb")
              "mise_rubygems_hook"
            elsif event.path.include?("/rubygems/")
              "rubygems"
            else
              "other"
            end
            report.call("path_mutation", {before_path_count: before[0], before_localbin: before[1], before_mise_on_scanned_path: before[2], source: source, line: event.lineno}) if mutations <= 3
          end
        end
      elsif defined?(ReshimInstaller) && event.self.equal?(ReshimInstaller) && event.event != :c_return
        if event.method_id == :reshim && calls.zero?
          calls += 1
          report.call("reshim_entry")
        elsif event.method_id == :` && calls == 1
          calls += 1
          report.call("reshim_backtick")
          trace.disable
        end
      end
    end
    trace.enable
    at_exit { report.call("loaded_no_callback") if calls.zero? }
  end
end
