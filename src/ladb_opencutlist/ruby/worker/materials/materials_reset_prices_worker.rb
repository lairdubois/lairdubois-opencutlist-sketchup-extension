module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'

  class MaterialsResetPricesWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      materials = model ? model.materials : nil

      if materials
        materials.each { |material|

          material_attributes = MaterialAttributes.new(material)

          material_attributes.std_prices = nil
          material_attributes.std_cut_prices = nil
          material_attributes.write_to_attributes

        }

      end

    end

  end

end