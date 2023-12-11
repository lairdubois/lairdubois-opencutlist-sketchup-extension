module Ladb::OpenCutList

  require_relative '../../model/attributes/definition_attributes'

  class CutlistResetPricesWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      definitions = model ? model.definitions : nil

      if definitions
        definitions.each { |definition|

          definition_attributes = DefinitionAttributes.new(definition)
          definition_attributes.price = nil
          definition_attributes.write_to_attributes

        }

      end

    end

  end

end