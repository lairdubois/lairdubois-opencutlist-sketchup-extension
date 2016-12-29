require 'base64'
require 'uri'

module Ladb
  module Toolbox
    class Controller

      @plugin
      @tab_name

      def initialize(plugin, tab_name)
        @plugin = plugin
        @tab_name = tab_name
      end

      def setup_commands()
      end

    end
  end
end