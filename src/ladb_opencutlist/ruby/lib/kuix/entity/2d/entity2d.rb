module Ladb::OpenCutList::Kuix

  class Entity2d < Entity

    attr_reader :bounds
    attr_reader :margin, :border, :padding, :gap
    attr_reader :min_size
    attr_reader :background_color, :border_color, :color
    attr_accessor :layout, :layout_data

    def initialize(id = nil)
      super(id)

      # Computed bounds of the widget relative to its parent
      @bounds = Bounds2d.new

      @margin = Inset2d.new
      @border = Inset2d.new
      @padding = Inset2d.new

      @min_size = Size2d.new

      @background_color = nil
      @border_color = nil
      @color = nil

      @styles = {
        :default => {}
      }
      @active_pseudo_classes = []

      @layout = nil
      @layout_data = nil

      @hittable = true

    end

    # -- PROPERTIES --

    def insets
      Inset2d.new(
        @margin.top + @border.top + @padding.top,
        @margin.right + @border.right + @padding.right,
        @margin.bottom + @border.bottom + @padding.bottom,
        @margin.left + @border.left + @padding.left
      )
    end

    def content_size
      insets = self.insets
      Size2d.new(
        @bounds.size.width - insets.left - insets.right,
        @bounds.size.height - insets.top - insets.bottom,
      )
    end

    def get_preferred_size(preferred_width)
      size = Size2d.new
      if @layout
        @layout.measure_preferred_size(self, preferred_width, size)
      else
        insets = self.insets
        size.set!(
          insets.left + @min_size.width + insets.right,
          insets.top + @min_size.height + insets.bottom
        )
      end
      size
    end

    def hittable=(value)
      @hittable = value
    end

    def hittable?(event = nil)
      @hittable && (@background_color || @border_color)
    end

    def valid?
      !@bounds.empty?
    end

    # -- STYLE --

    def propagable_pseudo_class(pseudo_class, depth)
      true
    end

    def activate_pseudo_class(pseudo_class, depth = 0)
      unless @active_pseudo_classes.include?(pseudo_class)
        @active_pseudo_classes.push(pseudo_class)
        @child.activate_pseudo_class(pseudo_class, depth + 1) if @child && @child.propagable_pseudo_class(pseudo_class, depth + 1)
        @next.activate_pseudo_class(pseudo_class, depth) if @next && @next.propagable_pseudo_class(pseudo_class, depth) && depth > 0
        invalidate
      end
    end

    def deactivate_pseudo_class(pseudo_class, depth = 0)
      if @active_pseudo_classes.include?(pseudo_class)
        @active_pseudo_classes.delete(pseudo_class)
        @child.deactivate_pseudo_class(pseudo_class, depth + 1) if @child && @child.propagable_pseudo_class(pseudo_class, depth + 1)
        @next.deactivate_pseudo_class(pseudo_class, depth) if @next && @next.propagable_pseudo_class(pseudo_class, depth) && depth > 0
        invalidate
      end
    end

    def has_pseudo_class?(pseudo_class)
      @active_pseudo_classes.include?(pseudo_class)
    end

    def set_style_attribute(attribute, value, pseudo_class = :default)
      unless @styles.has_key?(pseudo_class)
        @styles[pseudo_class] = {}
      end
      @styles[pseudo_class][attribute] = value
      invalidate
    end

    def do_style

      # Default values
      @background_color = @styles[:default][:background_color]
      @border_color = @styles[:default][:border_color]
      @color = @styles[:default][:color]

      @active_pseudo_classes.each do |pseudo_class|
        style = @styles[pseudo_class]
        if style
          @background_color = style[:background_color] if style.has_key?(:background_color)
          @border_color = style[:border_color] if style.has_key?(:border_color)
          @color = style[:color] if style.has_key?(:color)
        end
      end

    end

    # -- DOM --

    # Append given entity to self and returns self
    def append(entity)
      raise 'Widget.append only supports Widget' unless entity.is_a?(Entity2d)
      super
    end

    # -- LAYOUT --

    def do_layout
      do_style
      @layout.do_layout(self) if @layout
      self.invalidated = false
    end

    # -- Render --

    def paint_border(graphics)
      if @border_color

        width = @bounds.width - @margin.left - @margin.right
        height = @bounds.height - @margin.top - @margin.bottom

        graphics.set_drawing_color(@border_color)
        graphics.draw_rect(x: 0, y: 0, width: width - @border.right, height: @border.top)
        graphics.draw_rect(x: 0 + width - @border.right, y: 0, width: @border.right, height: height - @border.bottom)
        graphics.draw_rect(x: 0 + @border.left, y: 0 + height - @border.bottom, width: width - @border.left, height: @border.bottom)
        graphics.draw_rect(x: 0, y: 0 + @border.top, width: @border.left, height: height - @border.top)
      end
    end

    def paint_background(graphics)
      if @background_color

        width = @bounds.width - @margin.left - @border.left - @margin.right - @border.right
        height = @bounds.height - @margin.top - @border.top - @margin.bottom - @border.bottom

        graphics.draw_rect(x: 0, y: 0, width: width, height: height, fill_color: @background_color)
      end
    end

    def paint_itself(graphics)

      graphics.translate(@bounds.x + @margin.left, @bounds.y + @margin.top)
      paint_border(graphics)

      graphics.translate(@border.left, @border.top)
      paint_background(graphics)

      graphics.translate(@padding.left, @padding.top)
      super

      graphics.translate(-@bounds.x - @margin.left - @border.left - @padding.left, -@bounds.y - @margin.top - @border.top - @padding.top)

    end

    # -- Hit --

    def hit_widget(x, y, event = nil)
      widget = nil
      hit_bounds = Bounds2d.new(   # Exclude margin from hit test
        @bounds.origin.x + @margin.left,
        @bounds.origin.y + @margin.top,
        @bounds.size.width - @margin.left - @margin.right,
        @bounds.size.height - @margin.top - @margin.bottom
      )
      if self.visible? && hit_bounds.inside?(x, y)
        if @last_child
          widget = @last_child.hit_widget(
            x - hit_bounds.origin.x - @border.left - @padding.left,
            y - hit_bounds.origin.y - @border.top - @padding.top,
            event
          )
        end
        widget = self if widget.nil? && self.hittable?(event)
      end
      widget = @previous.hit_widget(x, y, event) if widget.nil? && @previous
      widget
    end

    # -- Events --

    def onMouseEnter(flags)
      activate_pseudo_class(:hover)
    end

    def onMouseLeave
      deactivate_pseudo_class(:active)
      deactivate_pseudo_class(:hover)
    end

    def onMouseDown(flags)
      activate_pseudo_class(:active)
    end

    def onMouseClick(flags)
      deactivate_pseudo_class(:active)
    end

    def onMouseDoubleClick(flags)
      deactivate_pseudo_class(:active)
    end

    def onMouseWheel(flags, delta)
    end

    # --

    def to_s
      "#{self.class.name} (id=#{@id}, bounds=#{@bounds})"
    end

  end

  module EventHandlerHelper

    # -- PROPERTIES --

    def hittable?(event = nil)
      super && (event.nil? || @handlers && @handlers[event])
    end

    # -- EVENTS --

    def on(events, &block)
      @handlers = {} if @handlers.nil?
      events = [ events ] unless events.is_a?(Array)
      events.each { |event| @handlers[event] = block }
    end

    def off(events)
      return if @handlers.nil?
      events = [ events ] unless events.is_a?(Array)
      events.each { |event| @handlers.delete!(event) }
    end

    def fire(events, *args)
      return if @handlers.nil?
      events = [ events ] unless events.is_a?(Array)
      events.map { |event|
        if @handlers[event]
          @handlers[event].call(self, *args)
          true
        else
          false
        end
      }.include?(true)
    end

  end

end