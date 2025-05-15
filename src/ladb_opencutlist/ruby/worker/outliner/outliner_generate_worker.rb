module Ladb::OpenCutList

  require 'benchmark'

  require_relative 'outliner_worker'
  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/outliner_def'
  require_relative '../../model/outliner/outliner_node_def'
  require_relative '../../model/outliner/outliner_material_def'
  require_relative '../../model/outliner/outliner_layer_def'
  require_relative '../../utils/color_utils'

  class OutlinerGenerateWorker

    include BoundingBoxHelper
    include LayerVisibilityHelper

    def initialize(

                   expanded_node_ids: []

    )

      @expanded_node_ids = expanded_node_ids

    end

    # -----

    def run

      model = Sketchup.active_model

      filename = model && !model.path.empty? ? File.basename(model.path) : PLUGIN.get_i18n_string('default.empty_filename')
      model_name = model && model.name

      outliner_def = OutlinerDef.new(filename, model_name)

      w = OutlinerWorker.new(outliner_def)

      # Errors
      unless model
        outliner_def.add_error('tab.outliner.error.no_model')
        return outliner_def
      end

      # Retrieve available materials and layers
      w.compute_available_materials
      w.compute_available_layers

      # Generate node tree
      outliner_def.root_node_def = w.run(:create_node_def, { entity: model })

      w.run(:compute_active_path)
      w.run(:compute_selection)

      @expanded_node_ids.each do |node_id|
        w.run(:expand_to, { id: node_id })
      end

      # Tips
      if outliner_def.root_node_def.children.length == 0
        outliner_def.add_tip('tab.outliner.tip.no_node')
      end

      outliner_def
    end

  end

end