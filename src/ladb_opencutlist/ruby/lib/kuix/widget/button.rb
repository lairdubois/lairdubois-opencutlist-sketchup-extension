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


  end

end