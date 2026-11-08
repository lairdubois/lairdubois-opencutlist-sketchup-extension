module Ladb::OpenCutList

  class ModelObserver < Sketchup::ModelObserver

    ON_ACTIVE_PATH_CHANGED = 'on_active_path_changed'.freeze
    ON_DRAWING_CHANGE = 'on_drawing_change'.freeze

    def onActivePathChanged(model)
      # puts "onActivePathChanged: #{model}"

      # Trigger event to JS
      PLUGIN.trigger_event(ON_ACTIVE_PATH_CHANGED, nil)

    end

    def onPreSaveModel(model)
      # puts "onPreSaveModel: #{model}"

      # Persists material's cached uuids (transparent operation : merged into the previous one)
      materials = model.materials.select { |material| MaterialAttributes.fetch_cached_uuid(material) }
      unless materials.empty?
        model.start_operation('OCL Persist Material UUIDs', true, false, true)
        materials.each do |material|
          MaterialAttributes.persist_cached_uuid_of(material)
        end
        model.commit_operation
      end

      # Force 'settings_model' preset to be stored in the model file if it contains default values
      # (permits to save default 'mass_unit', 'mass_precision', 'currency_symbol' and 'currency_precision' values to the file)
      settings_model_values, contains_default_values = PLUGIN.get_model_preset_context('settings_model')
      PLUGIN.set_model_preset('settings_model', settings_model_values) if contains_default_values

    end

    # -- OCL events

    def onDrawingChange
      # puts "onDrawingChange"

      # Trigger event to JS
      PLUGIN.trigger_event(ON_DRAWING_CHANGE, nil)

    end

  end

end