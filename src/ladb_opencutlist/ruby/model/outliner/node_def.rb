module Ladb::OpenCutList

  require 'digest'

  require_relative 'node'
  require_relative '../../utils/path_utils'

  class AbstractNodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    attr_accessor :default_name, :layer_def, :expanded, :part_count
    attr_reader :path, :entity, :id, :type, :children

    def initialize(path = [])
      @path = path
      @entity = @path.empty? ? Sketchup.active_model : path.last
      @id = Digest::MD5.hexdigest("#{@entity.guid}|#{PathUtils.serialize_path(path)}")

      @type = nil

      @default_name = nil

      @layer_def = nil

      @expanded = false
      @part_count = 0

      @children = []

    end

    # -----

    def create_node
      raise 'Abstract method : Override it'
    end

  end

  class NodeModelDef < AbstractNodeDef

    def initialize(path = [])
      super
      @type = TYPE_MODEL
    end

    # -----

    def create_node
      NodeModel.new(self)
    end

  end

  class NodeGroupDef < AbstractNodeDef

    attr_accessor :layer_name, :layer_folders

    def initialize(path = [])
      super
      @type = TYPE_GROUP

      @layer_name = nil
      @layer_folders = nil

    end

    # -----

    def create_node
      NodeGroup.new(self)
    end

  end

  class NodeComponentDef < NodeGroupDef

    attr_accessor :definition_name

    def initialize(path = [])
      super
      @type = TYPE_COMPONENT
    end

    # -----

    def create_node
      NodeComponent.new(self)
    end

  end

  class NodePartDef < NodeComponentDef

    def initialize(path = [])
      super
      @type = TYPE_PART
    end

    # -----

    def create_node
      NodePart.new(self)
    end

  end

end