module Ladb::OpenCutList

  require 'singleton'

  class ModelObserver < Sketchup::ModelObserver

    include Singleton

    def onPreSaveModel(model)
      # puts "onPreSaveModel: #{model}"

      if Sketchup.version_number > 2010000000

        # Persists material persistent_ids to uuids
        model.materials.each { |material|
          MaterialAttributes.write_persistent_id_to_uuid(material)
        }

      end

    end

  end

end