module Ladb::OpenCutList

  module Layer0Caching

    # Layer0 cache for intensive call
    @layer0 = Sketchup.active_model ? Sketchup.active_model.layers[0] : nil

  end

end