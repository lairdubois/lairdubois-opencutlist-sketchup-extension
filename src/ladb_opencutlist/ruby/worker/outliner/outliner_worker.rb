module Ladb::OpenCutList

  require_relative '../../helper/layer0_caching_helper'

  class OutlinerWorker

    include Layer0CachingHelper

    def initialize(outliner_def)

      @outliner_def = outliner_def

    end

    # -----

    def run(action, params = {})

      send(action, **params)

      @outliner_def
    end

    # -----

    def compute_available_materials
      return if @outliner_def.nil?

      model = Sketchup.active_model
      if model
        materials = []
        model.materials.each do |material|
          materials << material
          material_def = @outliner_def.get_material_def(material)
          if material_def
            material_def.fill
            material_def.clear_hashable
            material_def.each_used_by { |node_def| node_def.clear_hashable }
          else
            @outliner_def.add_material_def(OutlinerMaterialDef.new(material))
          end
        end
        (@outliner_def.available_material_defs.keys - materials).each do |material|
          @outliner_def.available_material_defs[material].each_used_by do |node_def|
            node_def.material_def = nil
            node_def.clear_hashable
          end
          @outliner_def.available_material_defs.delete(material)
        end
      end

    end

    def compute_available_layers
      return if @outliner_def.nil?

      model = Sketchup.active_model
      if model
        layers = []
        model.layers.each do |layer|
          next if layer == cached_layer0
          layers << layer
          layer_def = @outliner_def.get_layer_def(layer)
          if layer_def
            layer_def.fill
            layer_def.clear_hashable
            layer_def.each_used_by { |node_def| node_def.clear_hashable }
          else
            @outliner_def.add_layer_def(OutlinerLayerDef.new(layer))
          end
        end
        (@outliner_def.available_layer_defs.keys - layers).each do |layer|
          @outliner_def.available_layer_defs[layer].each_used_by do |node_def|
            node_def.layer_def = nil
            node_def.clear_hashable
          end
          @outliner_def.available_layer_defs.delete(layer)
        end
      end

    end

    def compute_active_path
      return if @outliner_def.nil?

      # Reset current active
      if @outliner_def.active_node_def

        @outliner_def.active_node_def.active = false
        @outliner_def.active_node_def.clear_hashable
        node_def = @outliner_def.active_node_def.parent
        while node_def
          node_def.child_active = false
          node_def.clear_hashable
          node_def = node_def.parent
        end
        @outliner_def.active_node_def = nil

      else

        @outliner_def.root_node_def.active = false
        @outliner_def.root_node_def.clear_hashable

      end

      # Compute new active nodes
      model = Sketchup.active_model
      if model && model.active_path

        active_node_def = @outliner_def.get_node_def_by_id(AbstractOutlinerNodeDef.generate_node_id(model.active_path))
        if active_node_def
          active_node_def.active = true
          active_node_def.clear_hashable
          node_def = active_node_def.parent
          while node_def
            node_def.child_active = true
            node_def.clear_hashable
            node_def = node_def.parent
          end
        end
        @outliner_def.active_node_def = active_node_def

      else

        @outliner_def.root_node_def.active = true
        @outliner_def.root_node_def.clear_hashable

      end
    end

    def compute_selection
      return if @outliner_def.nil?

      # Reset current selection
      @outliner_def.selected_node_defs.each do |node_def|
        node_def.selected = false
        node_def.clear_hashable
      end
      @outliner_def.selected_node_defs.clear

      model = Sketchup.active_model
      return if model.nil?

      model.selection
              .select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
              .flat_map { |entity| @outliner_def.get_node_defs_by_entity(entity) }
              .compact
              .each do |node_def|
        node_def.selected = true
        node_def.clear_hashable
        @outliner_def.selected_node_defs << node_def

      end

    end

    def toggle_expanded(id:)

      node_def = @outliner_def.get_node_def_by_id(id)
      if node_def

        node_def.expanded = !node_def.expanded
        node_def.clear_hashable

      end

    end

    def refetch_node_def(id:)

      node_def = @outliner_def.get_node_def_by_id(id)
      if node_def

      end

    end

  end

end