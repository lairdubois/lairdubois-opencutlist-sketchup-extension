module Ladb::OpenCutList

  require_relative 'outliner'

  class OutlinerDef

    attr_accessor :root_node_def, :active_node_def, :selected_node_defs
    attr_reader :errors, :warnings, :tips, :filename, :model_name, :available_material_defs, :available_layer_defs

    def initialize(filename, model_name)

      @errors = []
      @warnings = []
      @tips = []

      @filename = filename
      @model_name = model_name

      @available_material_defs = {}
      @available_layer_defs = {}

      @root_node_def = nil

      @active_node_def = nil
      @selected_node_defs = nil

      @node_defs_by_id = {}
      @node_defs_by_entity = {}

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

    # Materials

    def add_material_def(material_def)
      @available_material_defs[material_def.material] = material_def
    end

    # Layers

    def add_layer_def(layer_def)
      @available_layer_defs[layer_def.layer] = layer_def
    end

    # NodeDefs

    def add_node_def(node_def)
      @node_defs_by_id[node_def.id] = node_def
      nodes_cache = @node_defs_by_entity[node_def.entity]
      nodes_cache = @node_defs_by_entity[node_def.entity] = [] if nodes_cache.nil?
      nodes_cache.push(node_def)
    end

    def get_node_def_by_id(id)
      @node_defs_by_id[id]
    end

    def get_node_defs_by_entity(entity)
      @node_defs_by_entity[entity]
    end

    # ---

    def create_hashable
      Outliner.new(self)
    end

  end

end
