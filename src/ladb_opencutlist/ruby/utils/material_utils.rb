module Ladb::OpenCutList

  class MaterialUtils

    def self.get_material_from_path(path) # path is Array<Sketchup::Drawingelement>
      return nil if path.nil? || !path.is_a?(Array)
      entity = path.last
      material = nil
      if entity && entity.is_a?(Sketchup::Drawingelement)
        if entity.material
          material = entity.material
        elsif path.length > 0
          material = get_material_from_path(path[0...-1])
        end
      end
      material
    end

    def self.get_color_from_path(path)   # path is Array<Sketchup::Drawingelement>
      material = get_material_from_path(path)
      if material
        color = material.color
      else
        color = Sketchup::Color.new(255, 255, 255)  # No material. Default color is white
      end
      color
    end

  end

end

