module Ladb::OpenCutList

  class EgdesController < Controller

    def initialize()
      super('edges')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("edges_list") do
        list_command
      end

    end

    private

    # -- Commands --

    def list_command

      model = Sketchup.active_model

      response = {
          :errors => [],
          :length_unit => DimensionUtils.instance.length_unit,
      }

      # Check model
      unless model
        response[:errors] << 'tab.importer.error.no_model'
        return response
      end

    end

  end

end