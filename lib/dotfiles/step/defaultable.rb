class Dotfiles
  class Step
    module Defaultable
      def update_defaults_config(config_key, config_filename)
        updated_settings = setting_entries.group_by(&:first).transform_values do |entries|
          entries.filter_map { |domain, key, _value|
            read_command = build_read_command(domain, key)
            output, status = execute(read_command, quiet: true)
            [key, parse_defaults_value(output)] if status == 0
          }.to_h
        end

        content = {config_key => updated_settings}.to_yaml
        config_path = @system.path_join(@dotfiles_dir, "config", config_filename)
        @system.write_file(config_path, content)
      end

      def domain_flag_for(domain)
        (domain == "NSGlobalDomain") ? "-g" : domain
      end

      def build_read_command(domain, key)
        domain_flag = domain_flag_for(domain)
        "defaults read #{domain_flag} #{key}"
      end

      def parse_defaults_value(output)
        return output.to_f if output.include?(".")
        output.to_i
      end
    end
  end
end
