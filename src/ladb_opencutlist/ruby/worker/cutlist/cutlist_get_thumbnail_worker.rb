module Ladb::OpenCutList

  require_relative '../../plugin'
  require_relative 'cutlist_convert_to_three_worker'

  class CutlistGetThumbnailWorker

    def initialize(part_data, cutlist)

      @definition_id = part_data.fetch('definition_id')
      @id = part_data.fetch('id')

      @cutlist = cutlist

    end

    # -----

    def run
      response = {
          :thumbnail_file => nil,
          :three_model_def => nil
      }

      model = Sketchup.active_model
      return response unless model

      definitions = model.definitions
      definition = definitions[@definition_id]
      if definition

        if Sketchup.version_number >= 1800000000 && Plugin.instance.webgl_available

          # Convert part drawing to ThreeJS

          part = @cutlist.get_part(@id)
          return response unless part

          worker = CutlistConvertToThreeWorker.new([ part ])
          begin
            three_model_def = worker.run
          rescue => e
            Plugin.instance.dump_exception(e)
            return { :errors => [ 'default.error' ] }
          end

          response[:three_model_def] = three_model_def.to_hash

        else

          # Just generate a PNG thumbnail

          temp_dir = Plugin.instance.temp_dir
          component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
          unless Dir.exist?(component_thumbnails_dir)
            Dir.mkdir(component_thumbnails_dir)
          end

          thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
          definition.save_thumbnail(thumbnail_file)

          response[:thumbnail_file] = thumbnail_file

        end

      end

      response
    end

  end

end