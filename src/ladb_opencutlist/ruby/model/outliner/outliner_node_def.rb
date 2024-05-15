module Ladb::OpenCutList

  require 'digest'

  require_relative 'outliner_node'
  require_relative '../../utils/path_utils'

  class AbstractOutlinerNodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    attr_accessor :default_name, :expanded, :parent
    attr_reader :path, :id, :depth, :entity, :children

    # -----

    def self.generate_node_id(path)
      entity = path.empty? ? Sketchup.active_model : path.last
      Digest::MD5.hexdigest("#{entity.guid}|#{PathUtils.serialize_path(path)}")
    end

    # -----

    def initialize(path = [])
      @path = path
      @id = AbstractOutlinerNodeDef::generate_node_id(path)
      @depth = @path.length
      @entity = @path.empty? ? Sketchup.active_model : path.last

      @default_name = nil
      @expanded = false

      @parent = nil
      @children = []

    end

    def type
      raise NotImplementedError
    end

    def entity_locked?
      false
    end

    def parent_locked?
      return false if @parent.nil?
      @parent.locked?
    end

    def locked?
      entity_locked? || parent_locked?
    end

    def entity_visible?
      true
    end

    def layer_visible?
      true
    end

    def parent_visible?
      return true if @parent.nil?
      @parent.visible?
    end

    def visible?
      entity_visible? && layer_visible? && parent_visible?
    end

    # -----

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
      OutlinerNodeModel.new(self)
    end

  end

  class OutlinerNodeGroupDef < OutlinerNodeModelDef

    attr_accessor :material_def, :layer_def

    def initialize(path = [])
      super

      @material_def = nil
      @layer_def = nil

    end

    def entity_locked?
      @entity.locked?
    end

    def entity_visible?
      @entity.visible?
    end

    def layer_visible?
      return true if @layer_def.nil?
      @layer_def.folders_visible? && @layer_def.visible?
    end

    def type
      TYPE_GROUP
    end

    # -----

    def create_hashable
      OutlinerNodeGroup.new(self)
    end

  end

  class OutlinerNodeComponentDef < OutlinerNodeGroupDef

    def initialize(path = [])
      super
      @type = TYPE_COMPONENT
    end

    # -----

    def create_hashable
      OutlinerNodeComponent.new(self)
    end

  end

  class OutlinerNodePartDef < OutlinerNodeComponentDef

    def initialize(path = [])
      super
    end

    def type
      TYPE_PART
    end

    # -----

    def create_hashable
      OutlinerNodePart.new(self)
    end

  end

end