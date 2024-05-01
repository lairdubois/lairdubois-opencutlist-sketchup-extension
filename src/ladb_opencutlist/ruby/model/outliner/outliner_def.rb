module Ladb::OpenCutList

  require_relative 'outliner'

  class OutlinerDef

    attr_accessor :root_node_def, :available_layer_defs
    attr_reader :errors, :warnings, :tips, :filename, :model_name

    def initialize(filename, model_name)

      @errors = []
      @warnings = []
      @tips = []

      @filename = filename
      @model_name = model_name

      @root_node_def = nil

      @available_layer_defs = {}

    end

    # ---

    # Errors

    def add_error(error)
      @errors.push(error)
    end

    # Warnings

    def add_warning(warning)
      @warnings.push(warning)
    end

    # Tips

    def add_tip(tip)
      @tips.push(tip)
    end

    # Layers

    def add_layer_def(layer_def)
      @available_layer_defs[layer_def.layer] = layer_def
    end

    # ---

    def create_outliner
      Outliner.new(self)
    end

  end

end
