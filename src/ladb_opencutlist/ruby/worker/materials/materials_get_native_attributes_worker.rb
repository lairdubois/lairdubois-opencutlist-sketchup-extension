module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'

  class MaterialsGetNativeAttributesWorker

    def initialize(settings)
      @type = settings['type'].to_i
    end

    # -----


    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      {
          :errors => [],
          :thickness => MaterialAttributes.get_native_value(@type, :thickness),
          :length_increase => MaterialAttributes.get_native_value(@type, :length_increase),
          :width_increase => MaterialAttributes.get_native_value(@type, :width_increase),
          :thickness_increase => MaterialAttributes.get_native_value(@type, :thickness_increase),
          :std_lengths => MaterialAttributes.get_native_value(@type, :std_lengths),
          :std_widths => MaterialAttributes.get_native_value(@type, :std_widths),
          :std_thicknesses => MaterialAttributes.get_native_value(@type, :std_thicknesses),
          :std_sections => MaterialAttributes.get_native_value(@type, :std_sections),
          :std_sizes => MaterialAttributes.get_native_value(@type, :std_sizes),
          :grained => MaterialAttributes.get_native_value(@type, :grained),
          :edge_decremented => MaterialAttributes.get_native_value(@type, :edge_decremented),
      }
    end

    # -----

  end

end