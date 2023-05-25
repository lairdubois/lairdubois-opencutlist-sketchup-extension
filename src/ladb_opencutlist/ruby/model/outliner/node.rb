module Ladb::OpenCutList

  require 'digest'

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'

  class Node

    include DefHelper
    include HashableHelper

    attr_accessor :name, :definition_name, :layer_name, :visible, :part_count
    attr_reader :id, :children

    def initialize(_def)
      @_def = _def

      @id = _def.id
      @type = _def.type
      @name = _def.name
      @definition_name = _def.definition_name
      @layer_name = _def.layer_name
      @visible = _def.visible

      @part_count = _def.part_count

      @children = _def.children.map { |node_def| node_def.create_node }

    end

  end

end