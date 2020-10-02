module Ladb::OpenCutList

  module Layer0CachingHelper

    # Layer0 cache for intensive call
    @layer0 = nil

    def cached_layer0
      if @layer0.nil?
        @layer0 = Sketchup.active_model ? Sketchup.active_model.layers[0] : nil
      end
      @layer0
    end

  end

end