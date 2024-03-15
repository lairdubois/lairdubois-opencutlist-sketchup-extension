module Ladb::OpenCutList

  class Controller

    @tab_name

    def initialize(tab_name)
      @tab_name = tab_name
    end

    def setup_commands
    end

    def setup_event_callbacks
    end

    protected

    def _symbolize(hash)
      return hash.transform_keys { |k| k.to_sym } if hash.respond_to?(:transform_keys)
      # Workaround for Ruby prior to 2.5
      h = {}
      hash.each_pair { |key, value| h[key.to_sym] = value }
      h
    end

  end
end