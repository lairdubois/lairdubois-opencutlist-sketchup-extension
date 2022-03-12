module Ladb::OpenCutList::Kuix

  class Label < Widget

    attr_accessor :text, :text_options

    def initialize(id = '')
      @text = ''
      @text_options = {
          :font => 'Verdana',
          :size => 15,
          :bold => false,
          :align => TextAlignCenter,
          :vertical_align => TextVerticalAlignCenter
      }
      super
    end

    # -- Render --

    def paint_content(graphics)
      super
      graphics.draw_text(@width / 2, @height / 2, @text, @text_options, @color)
    end

  end

end