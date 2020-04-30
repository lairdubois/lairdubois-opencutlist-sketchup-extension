module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class MaterialUsage

    include HashableHelper

    attr_accessor :name, :display_name, :type, :color, :use_count

    def initialize(name, display_name, type, color)
      @name = name
      @display_name = display_name
      @type = type
      @color = color
      @use_count = 0
    end

    # -----

    def to_hash
      hash = super.to_hash
      hash['color'] = @color.nil? ? nil : "#%02x%02x%02x" % [ @color.red, @color.green, @color.blue ]
      hash
    end

  end

end