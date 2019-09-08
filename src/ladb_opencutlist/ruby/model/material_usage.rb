module Ladb::OpenCutList

  class MaterialUsage

    attr_accessor :name, :display_name, :type, :color, :use_count

    def initialize(name, display_name, type, color)
      @name = name
      @display_name = display_name
      @type = type
      @color = color
      @use_count = 0
    end

    # -----

    def to_struct
      {
          :name => @name,
          :display_name => @display_name,
          :type => @type,
          :color => @color.nil? ? nil : "#%02x%02x%02x" % [ @color.red, @color.green, @color.blue ],
          :use_count => @use_count,
      }
    end

  end

end