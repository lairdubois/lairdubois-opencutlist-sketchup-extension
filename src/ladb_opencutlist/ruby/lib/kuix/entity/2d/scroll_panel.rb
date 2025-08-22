module Ladb::OpenCutList::Kuix

  class ScrollPanel < Entity2d

    include EventHandlerHelper

    def initialize(num_cols = 1, num_rows = 1, id = nil)
      super(id)

      self.set_viewport(num_cols, num_rows)
      self.on(:wheel) do |entity, flags, delta|
        scroll(-delta)
      end

      @scroll_btns_panel = nil
      @scroll_up_button = nil
      @scroll_down_button = nil

    end

    # -- PROPERTIES --

    def set_viewport(num_cols, num_rows)
      self.layout = GridLayout.new(num_cols, num_rows)
      self.scroll(0)
      @scroll_btns_panel.visible = self.num_children > num_cols * num_rows unless @scroll_btns_panel.nil?
    end

    # -- BUTTONS --

    def bind_scroll_btns_panel(panel)
      @scroll_btns_panel = panel
    end

    def bind_scroll_up_btn(btn)
      @scroll_up_button = btn
      btn.on([ :click, :doubleclick ]) do
        scroll(-1)
      end
    end

    def bind_scroll_down_btn(btn)
      @scroll_down_button = btn
      btn.on([ :click, :doubleclick ]) do
        scroll(1)
      end
    end

    # -- SCROLL --

    def scroll(delta = 1)
      min = 0
      max = layout.compute_num_rows_max(self) - layout.num_rows
      layout.start_row = [[ layout.start_row + delta, min ].max, max ].min
      @scroll_up_button.disabled = layout.start_row == min unless @scroll_up_button.nil?
      @scroll_down_button.disabled = layout.start_row == max unless @scroll_down_button.nil?
      invalidate
    end

    # -- EVENTS --

    def onMouseWheel(flags, delta)
      super
      fire(:wheel, flags, delta)
    end

  end

end