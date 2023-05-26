module Ladb::OpenCutList

  require 'digest'

  require_relative 'node'
  require_relative '../../utils/path_utils'

  class NodeDef

    TYPE_MODEL = 0
    TYPE_GROUP = 1
    TYPE_COMPONENT = 2
    TYPE_PART = 3

    attr_accessor :path, :type, :name, :definition_name, :layer_name, :layer_folders, :visible, :expended, :part_count
    attr_reader :id, :children

    def initialize(id, path = [])
      @id = id
      @path = path

      @type = nil
      @name = nil
      @definition_name = nil
      @layer_name = nil
      @layer_folders = nil
      @visible = true
      @expended = false

      @part_count = 0

      @children = []

    end

    # -----

    def self.generate_node_id(entity, path)
      Digest::MD5.hexdigest("#{entity.guid}|#{PathUtils.serialize_path(path)}")
    end

    # -----

    def entity
      return Sketchup.active_model if @path.empty?
      @path.last
    end

    # -----

    def create_node
      Node.new(self)
    end

  end

end