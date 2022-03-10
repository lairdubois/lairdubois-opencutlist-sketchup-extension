module Ladb::OpenCutList

  module ScreenScaleFactorHelper

    def _screen_scale(value)
      @screen_scale_factor = Sketchup.version_number >= 17000000 ? UI::scale_factor : 1.0 if @screen_scale_factor.nil?
      value * @screen_scale_factor
    end

  end

end