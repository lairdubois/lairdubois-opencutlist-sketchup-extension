module Ladb::OpenCutList

  require 'digest'

  require_relative 'outliner_node'
  require_relative '../../utils/path_utils'

  class AbstractOutlinerNodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    attr_accessor :default_name, :expanded, :child_active, :active, :selected, :parent
    attr_reader :path, :id, :depth, :entity, :entity_id, :children

    # -----

    def self.generate_node_id(path)
      entity = path.empty? ? Sketchup.active_model : path.last
      Digest::MD5.hexdigest("#{entity.guid}|#{PathUtils.serialize_path(path)}")
    end

    # -----

    def initialize(path = [])

      @path = path
      if @path.empty?
        @entity = Sketchup.active_model
        @entity_id = nil
      else
        @entity = path.last
        @entity_id = @entity.entityID
      end

      @id = AbstractOutlinerNodeDef::generate_node_id(path)
      @depth = @path.length

      @default_name = nil
      @expanded = false
      @child_active = false
      @active = false
      @selected = false

      @parent = nil
      @children = []

    end

    def type
      raise NotImplementedError
    end

    def locked?
      false
    end

    def computed_locked?
      locked? || (@parent.nil? ? false : @parent.locked?)
    end

    def visible?
      true
    end

    def computed_visible?
      visible? && (@parent.nil? ? true : @parent.computed_visible?)
    end

    # -----

    def clear_hashable
      @hashable = nil
      @parent.clear_hashable if @parent
    end

    def create_hashable
      raise NotImplementedError
    end

  end

  class OutlinerNodeModelDef < AbstractOutlinerNodeDef

    def type
      TYPE_MODEL
    end

    # -----

    def create_hashable
      @hashable = OutlinerNodeModel.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerNodeGroupDef < AbstractOutlinerNodeDef

    attr_accessor :material_def, :layer_def

    def initialize(path = [])
      super

      @material_def = nil
      @layer_def = nil

    end

    def material_def=(material_def)
      @material_def = material_def
      material_def.add_used_by_node_def(self) if material_def
    end

    def layer_def=(layer_def)
      @layer_def = layer_def
      layer_def.add_used_by_node_def(self) if layer_def
    end

    def locked?
      @entity.locked?
    end

    def visible?
      @entity.visible?
    end

    def computed_visible?
      super && (@layer_def.nil? ? true : @layer_def.computed_visible?)
    end

    def type
      TYPE_GROUP
    end

    # -----

    def create_hashable
      @hashable = OutlinerNodeGroup.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerNodeComponentDef < OutlinerNodeGroupDef

    def type
      TYPE_COMPONENT
    end

    # -----

    def create_hashable
      @hashable = OutlinerNodeComponent.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerNodePartDef < OutlinerNodeComponentDef

    def type
      TYPE_PART
    end

    # -----

    def create_hashable
      @hashable = OutlinerNodePart.new(self) if @hashable.nil?
      @hashable
    end

  end

end