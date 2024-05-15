module Ladb::OpenCutList

  require 'digest'

  require_relative 'outliner_node'
  require_relative '../../utils/path_utils'

  class AbstractOutlinerNodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    attr_accessor :default_name, :expanded, :part_count
    attr_reader :path, :entity, :id, :entity_id, :type, :children

    def initialize(path = [])
      @path = path
      @depth = @path.length
      @entity = @path.empty? ? Sketchup.active_model : path.last
      @id = Digest::MD5.hexdigest("#{@entity.guid}|#{PathUtils.serialize_path(path)}")
      @entity_id = @entity.nil? ? '' : @entity.entityID

      @type = nil

      @default_name = nil

      @expanded = false
      @part_count = 0

      @children = []

    end

    # -----

    def create_hashable
      raise NotImplementedError
    end

  end

  class OutlinerNodeModelDef < AbstractOutlinerNodeDef

    def initialize(path = [])
      super
      @type = TYPE_MODEL
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
      @type = TYPE_GROUP

      @material_def = nil
      @layer_def = nil

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
      @type = TYPE_PART
    end

    # -----

    def create_hashable
      OutlinerNodePart.new(self)
    end

  end

end