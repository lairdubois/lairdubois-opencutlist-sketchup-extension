module Ladb::OpenCutList::Kuix

  class Button < Widget

    attr_accessor :selected

    def initialize(id = nil, &on_click)
      super(id)

      @on_click = on_click

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

    def onMouseClick(flags)
      super
      if @on_click
        @on_click.call(self)
      end
    end


  end

end