class Dotfiles
  class Step
    module Defaultable
      def defaults_complete?(setting_type_name, current_host: false)
        setting_entries.each { |entry| check_setting(setting_type_name, entry, current_host) }
        @errors.empty?
      end

      def check_setting(setting_type_name, entry, current_host)
        domain, key, expected_value = entry
        expected_str = expected_value.is_a?(String) ? expected_value : expected_value.to_s
        read_cmd = build_read_command(domain, key, current_host: current_host)
        add_error("#{setting_type_name} setting #{domain}.#{key} not set to #{expected_value}") unless defaults_read_equals?(read_cmd, expected_str)
      end

      def run_defaults_write
        setting_entries.each do |domain, key, value|
          domain_flag = domain_flag_for(domain)
          type_flag = type_flag_for(value)
          execute("defaults write #{domain_flag} #{key} #{type_flag} #{value}")
        end
      end

      def update_defaults_config(config_key, _config_filename = nil)
        updated_settings = gather_current_settings
        write_to_config_file(config_key, updated_settings)
      end

      def gather_current_settings
        setting_entries.group_by(&:first).transform_values { |entries| read_entries_to_hash(entries) }
      end

      def read_entries_to_hash(entries)
        entries.filter_map { |domain, key, _| read_single_entry(domain, key) }.to_h
      end

      def read_single_entry(domain, key)
        output, status = execute(build_read_command(domain, key), quiet: true)
        return nil unless status == 0
        [key, collapse_path_to_home(parse_defaults_value(output))]
      end

      def write_to_config_file(config_key, updated_settings)
        config_path = File.join(@dotfiles_dir, "config", "config.yml")
        existing_config = YAML.safe_load(@system.read_file(config_path), permitted_classes: [Symbol]) || {}
        existing_config[config_key] = updated_settings
        @system.write_file(config_path, existing_config.to_yaml)
      end

      def domain_flag_for(domain)
        (domain == "NSGlobalDomain") ? "-g" : domain
      end

      def build_read_command(domain, key, current_host: false)
        domain_flag = domain_flag_for(domain)
        host_flag = current_host ? "-currentHost " : ""
        "defaults #{host_flag}read #{domain_flag} #{key}"
      end

      def type_flag_for(value)
        case value
        when Integer then "-int"
        when Float then "-float"
        when String then "-string"
        else "-int"
        end
      end

      def parse_defaults_value(output)
        str = output.strip
        return str.to_i if str.match?(/^-?\d+$/)
        return str.to_f if str.match?(/^-?\d+\.\d+$/)
        str
      end

      # Default implementation for setting_entries
      # Steps can override config_key to use different config keys
      def setting_entries
        return [] unless respond_to?(:config_key, true)
        settings = @config.fetch(config_key, {})
        settings.flat_map do |domain, domain_settings|
          domain_settings.map { |key, value| [domain, key, value] }
        end
      end
    end
  end
end
