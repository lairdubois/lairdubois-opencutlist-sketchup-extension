module Ladb::OpenCutList

  require 'digest'

  require_relative 'outliner_node'
  require_relative '../../utils/path_utils'

  class AbstractOutlinerNodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    PROPAGATION_SELF = 1 << 1
    PROPAGATION_UP =   1 << 2
    PROPAGATION_DOWN = 1 << 3

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
      @entity = @path.empty? ? Sketchup.active_model : @path.last
      @entity_id = @entity.entityID

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

    def valid?
      !@entity.nil? && @entity.valid?
    end

    def locked?
      false
    end

    def computed_locked?
      locked? || (@parent.nil? ? false : @parent.computed_locked?)
    end

    def visible?
      true
    end

    def computed_visible?
      visible? && (@parent.nil? ? true : @parent.computed_visible?)
    end

    def expandable?
      @children.any?
    end

    # -----

    def add_child(node_def)
      children << node_def
      node_def.parent = self
    end

    def remove_child(node_def)
      children.delete(node_def)
      node_def.parent = nil
    end

    # -----

    def invalidated?
      @hashable == nil
    end

    def invalidate(propagation = PROPAGATION_SELF | PROPAGATION_UP)
      @hashable = nil if (propagation & PROPAGATION_SELF == PROPAGATION_SELF)
      @parent.invalidate(PROPAGATION_SELF | PROPAGATION_UP) if (propagation & PROPAGATION_UP == PROPAGATION_UP) && @parent && !@parent.invalidated?
      @children.each { |child_node_def| child_node_def.invalidate(PROPAGATION_SELF | PROPAGATION_DOWN) unless child_node_def.invalidated? } if (propagation & PROPAGATION_DOWN == PROPAGATION_DOWN)
    end

    def get_hashable
      raise NotImplementedError
    end

  end

  class OutlinerNodeModelDef < AbstractOutlinerNodeDef

    def type
      TYPE_MODEL
    end

    # -----

    def get_hashable
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
      return if @material_def === material_def
      @material_def.remove_used_by_node_def(self) unless @material_def.nil?
      @material_def = material_def
      @material_def.add_used_by_node_def(self) unless @material_def.nil?
    end

    def layer_def=(layer_def)
      return if @layer_def === layer_def
      @layer_def.remove_used_by_node_def(self) unless @layer_def.nil?
      @layer_def = layer_def
      @layer_def.add_used_by_node_def(self) unless @layer_def.nil?
    end

    def locked?
      return super unless valid?
      @entity.locked?
    end

    def visible?
      return super unless valid?
      @entity.visible?
    end

    def computed_visible?
      super && (@layer_def.nil? ? true : @layer_def.computed_visible?)
    end

    def type
      TYPE_GROUP
    end

    # -----

    def get_hashable
      @hashable = OutlinerNodeGroup.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerNodeComponentDef < OutlinerNodeGroupDef

    def type
      TYPE_COMPONENT
    end

    # -----

    def get_hashable
      @hashable = OutlinerNodeComponent.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerNodePartDef < OutlinerNodeComponentDef

    def type
      TYPE_PART
    end

    # -----

    def get_hashable
      @hashable = OutlinerNodePart.new(self) if @hashable.nil?
      @hashable
    end

  end

end