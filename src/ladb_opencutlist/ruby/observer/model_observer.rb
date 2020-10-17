module Ladb::OpenCutList

  require 'singleton'

  class ModelObserver < Sketchup::ModelObserver

    include Singleton

    def onPreSaveModel(model)
      # puts "onPreSaveModel: #{model}"

      # Persists material's cached uuids
      model.materials.each { |material|
        MaterialAttributes.persist_cached_uuid_of(material)
      }

    end

  end

end