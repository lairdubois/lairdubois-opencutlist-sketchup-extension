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

      # Force 'settings_model' preset to be stored in model file (permits to save default 'mass_unit' and 'currency_symbol' values to file)
      settings_model = Plugin.instance.get_model_preset('settings_model')
      Plugin.instance.set_model_preset('settings_model', settings_model) unless settings_model.nil?

    end

  end

end