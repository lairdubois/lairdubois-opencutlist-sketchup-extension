module Ladb::OpenCutList::Kuix

  class Button < Entity2d

    include EventHandlerHelper

    attr_accessor :selected, :disabled

    def initialize(id = nil)
      super
    end

    # -- PROPERTIES --

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

    def disabled=(value)
      if value
        onMouseLeave if has_pseudo_class?(:hover)
        activate_pseudo_class(:disabled)
      else
        deactivate_pseudo_class(:disabled)
      end
    end

    def disabled?
      has_pseudo_class?(:disabled)
    end

    # -- STATIC --

    def append_static_label(text, text_size, text_color = nil)

      # Create a new label
      label = Label.new
      label.text = text
      label.text_size = text_size
      label.set_style_attribute(:color, text_color) if text_color
      if self.layout.is_a?(BorderLayout)
        label.layout_data = BorderLayoutData.new(BorderLayoutData::CENTER)
      else
        label.layout_data = StaticLayoutData.new(0, 0, 1.0, 1.0)
      end

      # Append it
      self.layout = StaticLayout.new unless self.layout
      self.append(label)

      label
    end

    # -- STYLE --

    def propagable_pseudo_class(pseudo_class, depth)
      depth == 0
    end

    # -- EVENTS --

    def fire(events, *args)
      return if disabled?
      super
    end

    def onMouseEnter(flags)
      return if disabled?
      super
      fire(:enter, flags)
    end

    def onMouseLeave
      return if disabled?
      super
      fire(:leave)
    end

    def onMouseDown(flags)
      return if disabled?
      super
    end

    def onMouseClick(flags)
      return if disabled?
      super
      fire(:click, flags)
    end

    def onMouseDoubleClick(flags)
      return if disabled?
      super
      fire(:doubleclick, flags)
    end

    def onMouseWheel(flags, delta)
      return if disabled?
      super
      fire(:wheel, flags, delta)
    end

  end

end