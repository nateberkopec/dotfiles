module RuboCop
  module Cop
    module Dotfiles
      class BanFileSystemClasses < Base
        MSG_FILE = "Use SystemAdapter instead of File.%<method>s"
        MSG_FILEUTILS = "Use SystemAdapter instead of FileUtils.%<method>s"
        MSG_DIR = "Use SystemAdapter instead of Dir.%<method>s"

        ALLOWED_FILE_METHODS = %i[
          basename
          dirname
          expand_path
          extname
          fnmatch?
          join
          split
        ].freeze

        def_node_matcher :file_method?, <<~PATTERN
          (send (const {nil? cbase} :File) $_method ...)
        PATTERN

        def_node_matcher :fileutils_method?, <<~PATTERN
          (send (const {nil? cbase} :FileUtils) $_method ...)
        PATTERN

        def_node_matcher :dir_method?, <<~PATTERN
          (send (const {nil? cbase} :Dir) $_method ...)
        PATTERN

        def on_send(node)
          if (method = file_method?(node))
            add_offense(node, message: format(MSG_FILE, method: method)) unless allowed_file_method?(method)
          elsif (method = fileutils_method?(node))
            add_offense(node, message: format(MSG_FILEUTILS, method: method))
          elsif (method = dir_method?(node))
            add_offense(node, message: format(MSG_DIR, method: method))
          end
        end

        private

        def allowed_file_method?(method)
          ALLOWED_FILE_METHODS.include?(method)
        end
      end
    end
  end
end
