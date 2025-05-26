module Ladb::OpenCutList::Kuix

  class Label < Entity2d

    attr_reader :text, :text_options

    def initialize(text = '', id = '')
      super(id)
      @text = text
      @text_options = {
        :font => 'Verdana',
        _text_pixel_size_option_key => 15,
        :bold => false,
        :align => TextAlignCenter
      }
      if Sketchup.version_number >= 2000000000
        @text_options[:vertical_align] = TextVerticalAlignCenter
      end
      @text_point = Point2d.new
    end

    # -- PROPERTIES --

    def text=(value)
      return if @text == value
      @text = value
      @truncated_text = value
      invalidate
    end

    def text_font=(value)
      return if @text_options[:font] == value
      @text_options[:font] = value
      invalidate
    end

    def _text_pixel_size=(value)
      return if @text_options[_text_pixel_size_option_key] == value
      @text_options[_text_pixel_size_option_key] = value
      invalidate
    end
    private :_text_pixel_size=

    def _text_pixel_size
      @text_options[_text_pixel_size_option_key]
    end
    private :_text_pixel_size

    def _text_pixel_size_option_key
      return :pixel_size if Sketchup.version_number >= 2500000000
      :size
    end
    private :_text_pixel_size_option_key

    def text_size=(value)
      self._text_pixel_size = Sketchup.version_number < 2500000000 && Sketchup.platform == :platform_win ? value * 0.75 : value  # Windows (SU2025-) workaround -> 0.75 = 72 / 96 dpi
    end

    def text_bold=(value)
      return if @text_options[:bold] == value
      @text_options[:bold] = value
      invalidate
    end

    def text_align=(value)
      return if @text_options[:align] == value
      @text_options[:align] = value
      invalidate
    end

    def text_vertical_align=(value)
      return if @text_options[:vertical_align] == value
      @text_options[:vertical_align] = value
      invalidate
    end

    # --

    def get_prefered_size(prefered_width)
      if !Sketchup.active_model.nil? && Sketchup.active_model.active_view.respond_to?(:text_bounds) # SU 2020+
        text_bounds = Sketchup.active_model.active_view.text_bounds(ORIGIN, @text, @text_options)
        @min_size.set!(
          text_bounds.width,
          text_bounds.height
        )
      else
        # Estimate text size
        @min_size.set!(
          @text.length * _text_pixel_size.to_i * 0.7,
          _text_pixel_size
        )
      end
      super
    end

    # -- LAYOUT --

    def do_style
      super
      @text_options[:color] = @color
    end

    def do_layout
      super

      avg_letter_width = @text.length > 0 ? @min_size.width / @text.length : nil

      # Compute text point
      content_size = self.content_size
      content_bounds = Bounds2d.new(0, 0, content_size.width, content_size.height)
      case @text_options[:align]
      when TextAlignCenter
        @text_point = content_bounds.center
      when TextAlignRight
        @text_point = content_bounds.corner(Bounds2d::CENTER_RIGHT)
      else
        @text_point = content_bounds.corner(Bounds2d::CENTER_LEFT)
      end
      if Sketchup.version_number < 2000000000
        @text_point.y -= _text_pixel_size # Workaround the "center" text to SU prior 2020 where text anchor is top
      end

      # Truncate text if necessary
      if avg_letter_width
        if content_size.width < @min_size.width
          text_width = @text.length * avg_letter_width
          if text_width > content_size.width
            @truncated_text = @text[0..(content_size.width / avg_letter_width).to_i]
          else
            @truncated_text = @text
          end
        else
          @truncated_text = @text
        end
      end

    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_text(
        x: @text_point.x,
        y: @text_point.y,
        text: @truncated_text,
        text_options: @text_options)
      super
    end

  end

end