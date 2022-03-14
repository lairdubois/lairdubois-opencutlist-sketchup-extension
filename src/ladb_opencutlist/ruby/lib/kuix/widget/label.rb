module Ladb::OpenCutList::Kuix

  class Label < Widget

    attr_reader :text, :text_options

    def initialize(id = '')
      @text = ''
      @text_options = {
          :font => 'Verdana',
          :size => 15,
          :bold => false,
          :align => TextAlignCenter
      }
      if Sketchup.version_number >= 2000000000
        @text_options[:vertical_align] = TextVerticalAlignCenter
      end
      @text_point = Point.new
      super
    end

    # -- Properties --

    def text=(value)
      @text = value
      invalidate
    end

    def text_font=(value)
      @text_options[:font] = value
      invalidate
    end

    def text_size=(value)
      @text_options[:size] = value
      @min_size.height = [ @min_size.height, value ].max
      invalidate
    end

    def text_bold=(value)
      @text_options[:bold] = value
      invalidate
    end

    def text_align=(value)
      @text_options[:align] = value
      invalidate
    end

    def text_vertical_align=(value)
      @text_options[:vertical_align] = value
      invalidate
    end

    def do_style
      super
      @text_options[:color] = @color
    end

    def do_layout
      super

      # Compute text point
      content_size = get_content_size
      content_bounds = Bounds.new(0, 0, content_size.width, content_size.height)
      case @text_options[:align]
      when TextAlignCenter
        @text_point = content_bounds.center
      when TextAlignRight
        @text_point = content_bounds.corner(Bounds::CENTER_RIGHT)
      else
        @text_point = content_bounds.corner(Bounds::CENTER_LEFT)
      end
      if Sketchup.version_number < 2000000000
        @text_point.y -= @text_options[:size] # Workaround the "center" text to SU prior 2020 where text anchor is top
      end

    end

    # -- Render --

    def paint_content(graphics)
      super
      graphics.draw_text(@text_point.x, @text_point.y, @text, @text_options, @color)
    end

  end

end