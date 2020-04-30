module Ladb::OpenCutList

  require_relative '../../utils/string_utils'

  class Section

    attr_accessor :width, :height

    def initialize(width = 0, height = 0)
      if width.is_a? String
        s_width, s_height = StringUtils.split_dxd(width)
        width = s_width.to_l
        height = s_height.to_l
      end
      @width = width
      @height = height
    end

    # -----

    def to_s
      @width.to_l.to_s + ' x ' + @height.to_l.to_s
    end

  end

end
