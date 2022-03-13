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
      super
    end

    # -- Properties --

    def text=(value)
      @text = value
    end

    def text_font=(value)
      @text_options[:font] = value
    end

    def text_size=(value)
      @text_options[:size] = value
      @min_size.height = [ @min_size.height, value ].max
    end

    def text_bold=(value)
      @text_options[:bold] = value
    end

    def text_align=(value)
      @text_options[:align] = value
    end

    def text_vertical_align=(value)
      @text_options[:vertical_align] = value
    end

    # -- Render --

    def paint_content(graphics)
      super
      content_size = get_content_size
      content_bounds = Bounds.new(0, 0, content_size.width, content_size.height)
      case @text_options[:align]
      when TextAlignCenter
        point = content_bounds.center
      when TextAlignRight
        point = content_bounds.corner(Bounds::CENTER_RIGHT)
      else
        point = content_bounds.corner(Bounds::CENTER_LEFT)
      end
      if Sketchup.version_number < 2000000000
        point.y -= @text_options[:size] # Workaround the "center" text to SU prior 2020 where text anchor is top
      end
      graphics.draw_text(point.x, point.y, @text, @text_options, @color)
    end

  end

end