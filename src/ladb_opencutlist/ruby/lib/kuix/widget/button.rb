module Ladb::OpenCutList::Kuix

  class Button < Widget

    attr_accessor :on_mouse_enter, :on_mouse_leave
    attr_accessor :selected

    def initialize(id = nil)
      super(id)

      @handlers = {}

      @selected = false

    end

    # -- Properties --

    def selected=(value)
      @selected = value
      if @selected
        activate_pseudo_class(:selected)
      else
        deactivate_pseudo_class(:selected)
      end
    end

    # -- Hit --

    def hittable?
      true
    end

    # -- Events --

    def on(event, &block)
      @handlers[event] = block
    end

    def fire(event, params = nil)
      if @handlers[event]
        @handlers[event].call(self, params)
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


  end

end