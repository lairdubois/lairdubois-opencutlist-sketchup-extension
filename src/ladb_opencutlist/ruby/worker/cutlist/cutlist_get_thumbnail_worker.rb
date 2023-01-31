module Ladb::OpenCutList

  class CutlistGetThumbnailWorker

    def initialize(part_data)

      @definition_id = part_data.fetch('definition_id')

    end

    # -----

    def run
      response = {
          :thumbnail_file => ''
      }

      model = Sketchup.active_model
      return response unless model

      definitions = model.definitions
      definition = definitions[@definition_id]
      if definition

        ##

        mesh_defs = []
        _populate_mesh_defs(definition, mesh_defs)

        response[:mesh_defs] = mesh_defs

        ##


        temp_dir = Plugin.instance.temp_dir
        component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
        unless Dir.exist?(component_thumbnails_dir)
          Dir.mkdir(component_thumbnails_dir)
        end

        thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
        definition.save_thumbnail(thumbnail_file)

        response[:thumbnail_file] = thumbnail_file
      end

      response
    end

    # -----

    def _populate_mesh_defs(definition_or_group, mesh_defs, transformation = nil)
      definition_or_group.entities.each do |entity|
        if entity.is_a?(Sketchup::Face)
          mesh_def =  entity.mesh.polygons.map { |polygon|
            polygon.map { |index|
              point = entity.mesh.point_at(index)
              point.transform!(transformation) if transformation
              [ point.x.to_f, point.y.to_f, point.z.to_f ]
            }.flatten
          }.flatten
          mesh_defs.push(mesh_def)
        elsif entity.is_a?(Sketchup::Group)
          _populate_mesh_defs(entity, mesh_defs, transformation ? transformation * entity.transformation : entity.transformation)
        elsif entity.is_a?(Sketchup::ComponentInstance)
          _populate_mesh_defs(entity.definition, mesh_defs, transformation ? transformation * entity.transformation : entity.transformation)
        end
      end
    end

  end

end