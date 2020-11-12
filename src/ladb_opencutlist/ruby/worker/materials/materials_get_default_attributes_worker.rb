module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'

  class MaterialsGetDefaultAttributesWorker

    def initialize(settings)
      @type = settings['type'].to_i
    end

    # -----


    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      {
          :errors => [],
          :thickness => MaterialAttributes.get_default(@type, :thickness),
          :length_increase => MaterialAttributes.get_default(@type, :length_increase),
          :width_increase => MaterialAttributes.get_default(@type, :width_increase),
          :thickness_increase => MaterialAttributes.get_default(@type, :thickness_increase),
          :std_lengths => MaterialAttributes.get_default(@type, :std_lengths),
          :std_widths => MaterialAttributes.get_default(@type, :std_widths),
          :std_thicknesses => MaterialAttributes.get_default(@type, :std_thicknesses),
          :std_sections => MaterialAttributes.get_default(@type, :std_sections),
          :std_sizes => MaterialAttributes.get_default(@type, :std_sizes),
          :grained => MaterialAttributes.get_default(@type, :grained),
          :edge_decremented => MaterialAttributes.get_default(@type, :edge_decremented),
      }
    end

    # -----

  end

end