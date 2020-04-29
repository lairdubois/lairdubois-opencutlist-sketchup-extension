module Ladb::OpenCutList

  class CutlistGetThumbnailWorker

    def initialize(part_data)
      @definition_id = part_data['definition_id']
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

        definition.refresh_thumbnail

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

  end

end