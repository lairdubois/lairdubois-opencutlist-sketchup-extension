module Ladb::OpenCutList::Kuix

  class Label < Widget

    attr_reader :text, :text_options

    def initialize(id = '')
      super(id)
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
    end

    # -- Properties --

    def text=(value)
      @text = value
      @truncated_text = value
      compute_min_size
      invalidate
    end

    def text_font=(value)
      @text_options[:font] = value
      invalidate
    end

    def text_size=(value)
      @text_options[:size] = value
      compute_min_size
      compute_letter_width
      invalidate
    end

    def text_bold=(value)
      @text_options[:bold] = value
      compute_min_size
      compute_letter_width
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
      content_size = self.content_size
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

      # Truncate text if necessary
      if @letter_width
        text_width = @text.length * @letter_width
        if text_width > content_size.width
          @truncated_text = @text[0..(content_size.width / @letter_width).to_i]
        else
          @truncated_text = @text
        end
      end

    end

    def compute_letter_width
      if @text_options[:size]
        if Sketchup.version_number < 2000000000 || Sketchup.active_model.nil?
          # Estimate letter width
          @letter_width = @text_options[:size].to_i * 0.7
        else
          text_bounds = Sketchup.active_model.active_view.text_bounds(Geom::Point3d.new, 'A', @text_options)
          @letter_width = text_bounds.width
        end
      end
    end

    def compute_min_size
      if @text_options[:size]
        if Sketchup.version_number < 2000000000 || Sketchup.active_model.nil?
          # Estimate text size
          @min_size.set(
            @text.length * @text_options[:size].to_i * 0.7,
            @text_options[:size]
          )
        else
          text_bounds = Sketchup.active_model.active_view.text_bounds(Geom::Point3d.new, @text, @text_options)
          @min_size.set(
            text_bounds.width,
            text_bounds.height
          )
        end
      end
    end

    # -- Render --

    def paint_content(graphics)
      super
      graphics.draw_text(@text_point.x, @text_point.y, @truncated_text, @text_options)
    end

  end

end