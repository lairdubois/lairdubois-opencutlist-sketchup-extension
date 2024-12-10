module Ladb::OpenCutList::Kuix

  class Label < Entity2d

    attr_reader :text, :text_options

    def initialize(text = '', id = '')
      super(id)
      @text = text
      @text_options = {
          :font => 'Verdana',
          :size => 15,
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
      compute_min_size
      invalidate
    end

    def text_font=(value)
      return if @text_options[:font] == value
      @text_options[:font] = value
      invalidate
    end

    def text_size=(value)
      size = Sketchup.platform == :platform_win ? value * 0.75 : value  # Windows workaround -> 0.75 = 72 / 96
      return if @text_options[:size] == size
      @text_options[:size] = size
      compute_min_size
      compute_letter_width
      invalidate
    end

    def text_bold=(value)
      return if @text_options[:bold] == value
      @text_options[:bold] = value
      compute_min_size
      compute_letter_width
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

    # -- LAYOUT --

    def do_style
      super
      @text_options[:color] = @color
    end

    def do_layout
      super

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
        @text_point.y -= @text_options[:size] # Workaround the "center" text to SU prior 2020 where text anchor is top
      end

      # Truncate text if necessary
      if @letter_width
        if content_size.width < @min_size.width
          text_width = @text.length * @letter_width
          if text_width > content_size.width
            @truncated_text = @text[0..(content_size.width / @letter_width).to_i]
          else
            @truncated_text = @text
          end
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
        if !Sketchup.active_model.nil? && Sketchup.active_model.active_view.respond_to?(:text_bounds) # SU 2020+
          text_bounds = Sketchup.active_model.active_view.text_bounds(Geom::Point3d.new, @text, @text_options)
          @min_size.set!(
            text_bounds.width,
            text_bounds.height
          )
        else
          # Estimate text size
          @min_size.set!(
            @text.length * @text_options[:size].to_i * 0.7,
            @text_options[:size]
          )
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