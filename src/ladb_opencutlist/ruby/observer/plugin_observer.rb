module Ladb::OpenCutList

  require 'singleton'
  require_relative '../utils/mass_utils'
  require_relative '../utils/price_utils'

  class PluginObserver

    include Singleton

    ON_GLOBAL_PRESET_CHANGED = 'on_global_preset_changed'.freeze
    ON_MODEL_PRESET_CHANGED = 'on_model_preset_changed'.freeze

    def onGlobalPresetChanged(dictonary, section)
      # puts "onGlobalPresetChanged: #{dictonary}, #{section}"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_GLOBAL_PRESET_CHANGED, { :dictionary => dictonary, :section => section })

    end

    def onModelPresetChanged(dictonary, section)
      # puts "onModelPresetChanged: #{dictonary}, #{section}"

      # Fetch new mass options
      MassUtils.instance.fetch_mass_options

      # Fetch new currency options
      PriceUtils.instance.fetch_currency_options

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_MODEL_PRESET_CHANGED, { :dictionary => dictonary, :section => section })

    end

  end

end