module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class MaterialUsage

    include HashableHelper

    attr_accessor :name, :display_name, :type, :color, :textured, :grained, :use_count

    def initialize(name, display_name, type, color, textured, grained)
      @name = name
      @display_name = display_name
      @type = type
      @color = color
      @textured = textured
      @grained = grained
      @use_count = 0
    end

    # -----

    def to_hash
      hash = super.to_hash
      hash['color'] = ColorUtils.color_to_hex(@color)
      hash
    end

  end

end