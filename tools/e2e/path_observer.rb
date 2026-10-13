if ENV["DOTF_PATH_DIAGNOSTIC"] == "1"
  report = lambda do |stage|
    home = ENV.fetch("HOME", "")
    localbin = File.join(home, ".local/bin")
    paths = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
    fields = {
      stage: stage,
      pid: Process.pid,
      path_count: paths.length,
      path_scan_complete: paths.length <= 64,
      localbin_on_path: paths.include?(localbin),
      mise_file: File.file?(File.join(localbin, "mise")),
      mise_executable: File.executable?(File.join(localbin, "mise")),
      mise_on_scanned_path: paths.first(64).any? { |path| File.executable?(File.join(path, "mise")) },
      shims_on_path: paths.include?(File.join(home, ".local/share/mise/shims")),
      system_bin_on_path: paths.include?("/usr/bin"),
      original_mise_localbin: ENV.fetch("__MISE_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin),
      original_bundle_localbin: ENV.fetch("BUNDLER_ORIG_PATH", "").split(File::PATH_SEPARATOR).include?(localbin)
    }
    %w[__MISE_DIFF __MISE_ORIG_PATH BUNDLER_ORIG_PATH BASH_ENV MISE_SHELL AUBE_SHIM_DIR RUBYOPT].each do |key|
      fields["present_#{key}"] = ENV.key?(key)
    end
    warn "e2e-path-diagnostic #{fields.map { |key, value| "#{key}=#{value}" }.join(" ")}"
  end
  if ENV.key?("DOTF_PATH_DIAGNOSTIC_STAGE")
    report.call(ENV.fetch("DOTF_PATH_DIAGNOSTIC_STAGE"))
  else
    calls = 0
    trace = TracePoint.new(:call, :c_call) do |event|
      next unless defined?(ReshimInstaller) && event.self.equal?(ReshimInstaller)
      if event.method_id == :reshim && calls.zero?
        calls += 1
        report.call("reshim_entry")
      elsif event.method_id == :"`" && calls == 1
        calls += 1
        report.call("reshim_backtick")
        trace.disable
      end
    end
    trace.enable
    at_exit { report.call("loaded_no_callback") if calls.zero? }
  end
end
