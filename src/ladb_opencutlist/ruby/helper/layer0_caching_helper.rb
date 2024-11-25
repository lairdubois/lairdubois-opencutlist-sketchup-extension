module Ladb::OpenCutList

  module Layer0CachingHelper

    def cached_layer0
      @layer0 = Sketchup.active_model ? Sketchup.active_model.layers[0] : nil if @layer0.nil?
      @layer0
    end

  end

end