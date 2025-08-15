module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer0_caching_helper'
  require_relative '../../model/outliner/outliner_node_def'
  require_relative '../../model/outliner/outliner_material_def'
  require_relative '../../model/outliner/outliner_layer_def'

  class OutlinerWorker

    include BoundingBoxHelper
    include Layer0CachingHelper

    def initialize(outliner_def)

      @outliner_def = outliner_def

    end

    # -----

    def run(action, params = nil)
      return send(action, **params) if params.is_a?(Hash)
      send(action)
    end

    # -----

    def compute_available_materials
      return if @outliner_def.nil?

      model = Sketchup.active_model
      return if model.nil?

      materials = []
      model.materials.each do |material|
        materials << material
        material_def = @outliner_def.get_material_def(material)
        if material_def
          material_def.fill
          material_def.invalidate
          material_def.each_used_by { |node_def| node_def.invalidate }
        else
          @outliner_def.add_material_def(OutlinerMaterialDef.new(material))
        end
      end
      (@outliner_def.available_material_defs.keys - materials).each do |material|
        @outliner_def.available_material_defs[material].each_used_by do |node_def|
          node_def.material_def = nil
          node_def.invalidate
        end
        @outliner_def.available_material_defs.delete(material)
      end

    end

    def compute_available_layers
      return if @outliner_def.nil?

      model = Sketchup.active_model
      return if model.nil?

      layers = []
      model.layers.each do |layer|
        next if layer == cached_layer0
        layers << layer
        layer_def = @outliner_def.get_layer_def(layer)
        if layer_def
          layer_def.fill
          layer_def.invalidate
          layer_def.each_used_by { |node_def| node_def.invalidate }
        else
          @outliner_def.add_layer_def(OutlinerLayerDef.new(layer))
        end
      end
      (@outliner_def.available_layer_defs.keys - layers).each do |layer|
        @outliner_def.available_layer_defs[layer].each_used_by do |node_def|
          node_def.layer_def = nil
          node_def.invalidate
        end
        @outliner_def.available_layer_defs.delete(layer)
      end

    end

    def compute_active_path
      return if @outliner_def.nil?

      # Reset current active
      if @outliner_def.active_node_def

        @outliner_def.active_node_def.active = false
        node_def = @outliner_def.active_node_def.parent
        while node_def
          node_def.child_active = false
          node_def = node_def.parent
        end
        @outliner_def.active_node_def.invalidate
        @outliner_def.active_node_def = nil

      else

        @outliner_def.root_node_def.active = false
        @outliner_def.root_node_def.invalidate

      end

      # Compute new active nodes
      model = Sketchup.active_model
      if model && model.active_path

        active_node_def = @outliner_def.get_node_def_by_id(OutlinerNodeDef.generate_node_id(model.active_path))
        if active_node_def

          active_node_def.active = true
          active_node_def.invalidate
          node_def = active_node_def.parent
          while node_def
            node_def.child_active = true
            node_def.invalidate
            node_def = node_def.parent
          end

        else

          puts 'active_node_def not found'

        end
        @outliner_def.active_node_def = active_node_def

      else

        @outliner_def.root_node_def.active = true
        @outliner_def.root_node_def.invalidate

      end

    end

    def compute_selection
      return if @outliner_def.nil?

      # Reset current selection
      @outliner_def.selected_node_defs.each do |node_def|
        node_def.selected = false
        node_def.invalidate
      end
      @outliner_def.selected_node_defs.clear

      model = Sketchup.active_model
      return if model.nil?

      model.selection
              .select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
              .flat_map { |entity| @outliner_def.get_node_defs_by_entity_id(entity.entityID) }
              .compact
              .each do |node_def|

        node_def.selected = true
        node_def.invalidate
        @outliner_def.selected_node_defs << node_def

      end

    end

    def expand_to(id:)

      unless (node_def = @outliner_def.get_node_def_by_id(id)).nil?

        node_def.expand

        return true
      end

      false
    end

    def toggle_expanded(id:)

      unless (node_def = @outliner_def.get_node_def_by_id(id)).nil?

        return false if !node_def.expandable? || node_def.child_active || node_def.active

        node_def.expanded = !node_def.expanded
        node_def.invalidate

        return true
      end

      false
    end

    def create_node_def(entity:, path: [], face_bounds_cache: {})
      node_def = nil
      if entity.is_a?(Sketchup::Group)

        path += [ entity ]

        node_def = OutlinerNodeGroupDef.new(path)
        node_def.default_name = PLUGIN.get_i18n_string("tab.outliner.type_#{OutlinerNodeDef::TYPE_GROUP}")
        node_def.material_def = @outliner_def.available_material_defs[entity.material]
        node_def.layer_def = @outliner_def.available_layer_defs[entity.layer]

        @outliner_def.add_node_def(node_def)

        create_children_node_defs(node_def: node_def, entities: entity.entities, path: path, face_bounds_cache: face_bounds_cache)

      elsif entity.is_a?(Sketchup::ComponentInstance)

        path += [ entity ]

        # Treat cuts_opening and always_face_camera behavior component instances as a simple component
        unless entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?

          face_bounds_cache[entity.definition] = _compute_faces_bounds(entity.definition) unless face_bounds_cache.has_key?(entity.definition)
          bounds = face_bounds_cache[entity.definition]
          unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

            # It's a part

            node_def = OutlinerNodePartDef.new(path)

          end

        end

        node_def = OutlinerNodeComponentDef.new(path) if node_def.nil?
        node_def.material_def = @outliner_def.available_material_defs[entity.material]
        node_def.layer_def = @outliner_def.available_layer_defs[entity.layer]

        @outliner_def.add_node_def(node_def)

        create_children_node_defs(node_def: node_def, entities: entity.definition.entities, path: path, face_bounds_cache: face_bounds_cache) unless node_def.live_component?

      elsif entity.is_a?(Sketchup::Model)

        dir, filename = File.split(entity.path)
        filename = PLUGIN.get_i18n_string('default.empty_filename') if filename.empty?

        node_def = OutlinerNodeModelDef.new(path)
        node_def.default_name = filename
        node_def.expanded = true

        @outliner_def.add_node_def(node_def)

        create_children_node_defs(node_def: node_def, entities: entity.entities, path: path, face_bounds_cache: face_bounds_cache)

      end

      node_def
    end

    def destroy_node_def(node_def:)

      node_def.invalidate

      node_def.parent.remove_child(node_def) if node_def.parent
      node_def.children.each { |child_node_def| destroy_node_def(node_def: child_node_def) }

      node_def.material_def.remove_used_by_node_def(node_def) if node_def.respond_to?(:material_def) && node_def.material_def
      node_def.layer_def.remove_used_by_node_def(node_def) if node_def.respond_to?(:layer_def) && node_def.layer_def

      @outliner_def.remove_node_def(node_def)

    end

    def create_children_node_defs(node_def:, entities:, path: [], face_bounds_cache: {})
      entities.each do |child_entity|
        next unless child_entity.is_a?(Sketchup::Group) || child_entity.is_a?(Sketchup::ComponentInstance)

        child_node_def = create_node_def(entity: child_entity, path: path, face_bounds_cache: face_bounds_cache)
        node_def.add_child(child_node_def) if child_node_def

      end
      sort_children_node_defs(children: node_def.children)
    end

    def sort_children_node_defs(children:)
      children.sort_by! do |node_def|
        if node_def.valid?
          [
            node_def.type,
            (node_def.entity.name.nil? || node_def.entity.name.empty?) ? 1 : 0,
            node_def.entity.name,
            node_def.default_name,
            node_def.entity.entityID
          ]
        else
          []
        end
      end
    end

  end

end