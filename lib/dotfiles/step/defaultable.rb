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
          execute(command("defaults", "write", domain_flag, key, type_flag, value))
        end
      end

      def domain_flag_for(domain)
        (domain == "NSGlobalDomain") ? "-g" : domain
      end

      def build_read_command(domain, key, current_host: false)
        domain_flag = domain_flag_for(domain)
        args = ["defaults"]
        args << "-currentHost" if current_host
        command(*args, "read", domain_flag, key)
      end

      def type_flag_for(value)
        case value
        when Integer then "-int"
        when Float then "-float"
        when String then "-string"
        else "-int"
        end
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
