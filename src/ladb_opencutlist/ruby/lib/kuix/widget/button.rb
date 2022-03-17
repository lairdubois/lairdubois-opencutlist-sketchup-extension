module Ladb::OpenCutList::Kuix

  class Button < Widget

    attr_accessor :selected

    def initialize(id = nil)
      super(id)

      # Event handlers
      @handlers = {}

    end

    # -- Properties --

    def selected=(value)
      if value
        activate_pseudo_class(:selected)
      else
        deactivate_pseudo_class(:selected)
      end
    end

    def selected?
      has_pseudo_class?(:selected)
    end

    # --

    def append_static_label(text, text_size, text_color = nil)

      # Create a new label
      label = Label.new
      label.text = text
      label.text_size = text_size
      label.set_style_attribute(:color, text_color) if text_color
      label.layout_data = StaticLayoutData.new(0, 0, 1.0, 1.0)

      # Append it
      self.layout = StaticLayout.new unless self.layout
      self.append(label)

      label
    end

    # -- Events --

    def on(event, &block)
      @handlers[event] = block
    end

    def off(event)
      @handlers.delete!(event)
    end

    def fire(event, *args)
      if @handlers[event]
        @handlers[event].call(self, args)
      end
    end

    def onMouseEnter(flags)
      super
      fire(:enter, flags)
    end

    def onMouseLeave
      super
      fire(:leave)
    end

    def onMouseClick(flags)
      super
      fire(:click, flags)
    end

    def onMouseDoubleClick(flags)
      super
      fire(:doubleclick, flags)
    end

  end

end