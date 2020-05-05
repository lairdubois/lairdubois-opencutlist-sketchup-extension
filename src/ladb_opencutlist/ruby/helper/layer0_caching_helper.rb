module Ladb::OpenCutList

  module Layer0CachingHelper

    # Layer0 cache for intensive call
    @layer0 = Sketchup.active_model ? Sketchup.active_model.layers[0] : nil

  end

end