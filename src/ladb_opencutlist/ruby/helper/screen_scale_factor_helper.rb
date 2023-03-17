module Ladb::OpenCutList

  module ScreenScaleFactorHelper

    def _screen_scale(value)
      @screen_scale_factor = UI::scale_factor if @screen_scale_factor.nil?
      value * @screen_scale_factor
    end

  end

end