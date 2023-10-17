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

      # Force 'settings_model' preset to be stored in model file if it contains default values
      # (permits to save default 'mass_unit', 'mass_precision', 'currency_symbol' and 'currency_precision' values to file)
      settings_model_values, contains_default_values = Plugin.instance.get_model_preset_context('settings_model')
      Plugin.instance.set_model_preset('settings_model', settings_model_values) if contains_default_values

    end

  end

end