if ENV["DOTF_PATH_DIAGNOSTIC"] == "1"
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
    parse = lambda do |depth, keep|
      entries += 1
      raise ArgumentError if depth > 8 || entries > 256
      tag = take.call(1).getbyte(0)
      case tag
      when 0..127 then tag
      when 160..191
        value = take.call(tag - 160)
        keep ? value : nil
      when 204..207 then take.call(2**(tag - 204)).unpack1({204 => "C", 205 => "n", 206 => "N", 207 => "Q>"}.fetch(tag))
      when 217..219
        value = take.call(take.call(2**(tag - 217)).unpack1({217 => "C", 218 => "n", 219 => "N"}.fetch(tag)))
        keep ? value : nil
      when 144..159, 220, 221
        if tag < 160
          count = tag - 144
        else
          width, format = {220 => [2, "n"], 221 => [4, "N"]}.fetch(tag)
          count = take.call(width).unpack1(format)
        end
        raise ArgumentError if count > 256
        values = Array.new(count) { parse.call(depth + 1, keep) }
        keep ? values : nil
      when 128..143, 222, 223
        if tag < 144
          count = tag - 128
        else
          width, format = {222 => [2, "n"], 223 => [4, "N"]}.fetch(tag)
          count = take.call(width).unpack1(format)
        end
        raise ArgumentError if count > 128
        pairs = []
        count.times do
          key = parse.call(depth + 1, keep)
          value = parse.call(depth + 1, keep && (depth > 0 || %w[v path].include?(key)))
          pairs << [key, value] if keep
        end
        raise ArgumentError unless !keep || pairs.map(&:first).uniq.length == count
        keep ? pairs.to_h : nil
      else raise ArgumentError
      end
    end
    result = parse.call(0, true)
    raise ArgumentError unless offset == data.bytesize && result.is_a?(Hash) && [1, 2].include?(result.fetch("v", 1)) && result.fetch("path", []).is_a?(Array) && result.fetch("path", []).all? { |path| path.is_a?(String) }
    result
  rescue LoadError, StandardError
    nil
  end
  signature = lambda do
    paths = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
    [paths.length, paths.include?(File.join(ENV.fetch("HOME", ""), ".local/bin")), paths.first(64).any? { |path| File.executable?(File.join(path, "mise")) }]
  end
  mutations = calls = records = 0
  report = lambda do |stage, extra = {}|
    next if records >= 6
    records += 1
    home = ENV.fetch("HOME", "")
    localbin = File.join(home, ".local/bin")
    project = File.join(home, ".dotfiles")
    paths = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
    diff = decode.call(ENV["__MISE_DIFF"])
    diff_paths = diff ? diff.fetch("path", []) : []
    bash_env = case ENV["BASH_ENV"]
    when nil then "unset"
    when "" then "empty"
    when File.join(home, ".config/bash/safety.bash") then "managed_safety"
    else "other"
    end
    fields = {stage: stage, pid: Process.pid, path_count: paths.length, path_scan_complete: paths.length <= 64, localbin_on_path: paths.include?(localbin), mise_file: File.file?(File.join(localbin, "mise")), mise_executable: File.executable?(File.join(localbin, "mise")), mise_on_scanned_path: signature.call.last, shims_on_path: paths.include?(File.join(home, ".local/share/mise/shims")), system_bin_on_path: paths.include?("/usr/bin"), original_mise_localbin: ENV.fetch("__MISE_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin), original_bundle_localbin: ENV.fetch("BUNDLER_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin), diff_ok: !diff.nil?, diff_version: diff ? diff.fetch("v", 1) : "unavailable", diff_path_count: diff_paths.length, diff_localbin: diff_paths.include?(localbin), diff_projectbin: diff_paths.include?(File.join(project, "bin")), diff_shims: diff_paths.include?(File.join(home, ".local/share/mise/shims")), cwd_project: Dir.pwd == project, cwd_home: Dir.pwd == home, bundler_loaded: Object.const_defined?(:Bundler, false) && !Object.autoload?(:Bundler), bash_env: bash_env, mutations: mutations, mutation_scan_complete: mutations <= 3}
    %w[__MISE_DIFF __MISE_ORIG_PATH BUNDLER_ORIG_PATH BASH_ENV MISE_SHELL AUBE_SHIM_DIR RUBYOPT MISE_CONFIG_FILE MISE_GLOBAL_CONFIG_FILE].each { |key| fields["present_#{key}"] = ENV.key?(key) }
    warn "e2e-entry-diagnostic #{fields.merge(extra).map { |key, value| "#{key}=#{value}" }.join(" ")}"
  rescue
    warn "e2e-entry-diagnostic stage=observer_error diagnostic_ok=false"
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
