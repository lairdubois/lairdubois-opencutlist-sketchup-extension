module Ladb::OpenCutList

  require_relative '../../plugin'
  require_relative 'cutlist_convert_to_three_worker'

  class CutlistGetThumbnailWorker

    def initialize(cutlist,

                   definition_id: ,
                   id:

    )

      @cutlist = cutlist

      @definition_id = CGI.unescape(definition_id)
      @id = id

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

        if Sketchup.version_number >= 1800000000 && PLUGIN.webgl_available?

          # Convert part drawing to ThreeJS

          part = @cutlist.get_part(@id)
          return response unless part

          worker = CutlistConvertToThreeWorker.new([ part ])
          begin
            three_model_def = worker.run
          rescue => e
            PLUGIN.dump_exception(e)
            return { :errors => [ 'default.error' ] }
          end

          response[:three_model_def] = three_model_def.to_hash

        else

          # Just generate a PNG thumbnail

          temp_dir = PLUGIN.temp_dir
          component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
          Dir.mkdir(component_thumbnails_dir) unless Dir.exist?(component_thumbnails_dir)

          thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
          definition.save_thumbnail(thumbnail_file)

          response[:thumbnail_file] = thumbnail_file

        end

      end

      response
    end

  end

end