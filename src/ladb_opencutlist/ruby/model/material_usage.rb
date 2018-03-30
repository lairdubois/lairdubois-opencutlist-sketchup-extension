module Ladb::OpenCutList

  class MaterialUsage

    attr_accessor :name, :display_name, :type, :use_count

    def initialize(name, display_name, type)
      @name = name
      @display_name = display_name
      @type = type
      @use_count = 0
    end

  end

end