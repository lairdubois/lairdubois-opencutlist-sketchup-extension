module Ladb::OpenCutList

  module ViewUtils

    def self.zoom_active_entities(view, factor = 1.5)
      view.zoom(view.model.active_entities)
      camera = view.camera
      camera.set(camera.target.offset(camera.direction.reverse, camera.target.distance(camera.eye) * factor), camera.target, camera.up)
    end

  end

end