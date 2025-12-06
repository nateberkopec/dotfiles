class Dotfiles
  class Step
    module Defaultable
      def defaults_complete?(setting_type_name, current_host: false)
        setting_entries.each do |domain, key, expected_value|
          expected_str = expected_value.is_a?(String) ? expected_value : expected_value.to_s
          read_cmd = build_read_command(domain, key, current_host: current_host)
          unless defaults_read_equals?(read_cmd, expected_str)
            add_error("#{setting_type_name} setting #{domain}.#{key} not set to #{expected_value}")
          end
        end
        @errors.empty?
      end

      def run_defaults_write
        setting_entries.each do |domain, key, value|
          domain_flag = domain_flag_for(domain)
          type_flag = type_flag_for(value)
          execute("defaults write #{domain_flag} #{key} #{type_flag} #{value}")
        end
      end

      def update_defaults_config(config_key, _config_filename = nil)
        updated_settings = setting_entries.group_by(&:first).transform_values do |entries|
          entries.filter_map { |domain, key, _value|
            read_command = build_read_command(domain, key)
            output, status = execute(read_command, quiet: true)
            next unless status == 0

            value = parse_defaults_value(output)
            [key, collapse_path_to_home(value)]
          }.to_h
        end

        config_path = File.join(@dotfiles_dir, "config", "config.yml")
        existing_content = @system.read_file(config_path)
        existing_config = YAML.safe_load(existing_content, permitted_classes: [Symbol]) || {}
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
        when 0, 1
          "-int"
        when Integer
          "-int"
        when Float
          "-float"
        when String
          "-string"
        else
          "-int"
        end
      end

      def parse_defaults_value(output)
        return output.to_f if output.include?(".")
        return output.to_i if output.match?(/^-?\d+$/)
        output
      end
    end
  end
end
