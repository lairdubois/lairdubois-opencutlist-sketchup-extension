module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Outliner

    include DefHelper
    include HashableHelper

    attr_accessor :root_node, :available_materials, :available_layers
    attr_reader :errors, :warnings, :tips, :filename, :model_name

    def initialize(_def)
      @_def = _def

      @_obsolete = false
      @_observers = []

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @filename = _def.filename
      @model_name = _def.model_name

      @root_node = _def.root_node_def.nil? ? nil : _def.root_node_def.create_hashable

      @available_materials = _def.available_material_defs.values.map { |material_def| material_def.create_hashable }.sort_by { |v| [ MaterialAttributes.type_order(v.type), v.display_name.downcase ] }
      @available_layers = _def.available_layer_defs.values.map { |layer_def| {
        :name => layer_def.layer.name,
        :path => layer_def.folder_defs.map { |folder_def| folder_def.layer_folder.name },
        :color => ColorUtils.color_to_hex(layer_def.layer.color)
      } }

    end

    # ---

    def invalidate
      @_obsolete = true
      _fire_invalidate_event
    end

    def obsolete?
      @_obsolete
    end

    # Nodes

    def get_node(id, parent_node = nil)
      parent_node = @root_node if parent_node.nil?
      return parent_node if parent_node.id == id
      parent_node.children.each do |child_node|
        node = get_node(id, child_node)
        return node unless node.nil?
      end
      nil
    end

    def get_node_by_path(path, parent_node = nil)
      parent_node = @root_node if parent_node.nil?
      return parent_node if parent_node.nil? || parent_node.def.path == path
      parent_node.children.each do |child_node|
        node = get_node_by_path(path, child_node)
        return node unless node.nil?
      end
      nil
    end

    def get_nodes_by_entity(entity, parent_node = nil)
      parent_node = @root_node if parent_node.nil?
      return [ parent_node ] if parent_node.def.entity == entity
      nodes = []
      parent_node.children.each do |child_node|
        nodes += get_nodes_by_entity(entity, child_node)
      end
      nodes
    end

    private

    def _fire_invalidate_event
      @_observers.each do |observer|
        observer.onInvalidateOutliner(self)
      end
    end

  end

  module OutlinerObserverHelper

    def onInvalidateOutliner(outliner)
    end

  end

end
