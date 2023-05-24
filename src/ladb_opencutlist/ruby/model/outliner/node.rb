module Ladb::OpenCutList

  require 'digest'

  require_relative '../../helper/hashable_helper'

  class Node

    include HashableHelper

    attr_accessor :name, :definition_name, :visible, :part_count
    attr_reader :id, :nodes

    def initialize(id)
      @id = id

      @name = nil
      @definition_name = nil
      @visible = true

      @part_count = 0

      @nodes = []
    end

    # -----

    def self.generate_node_id(entity, path)
      Digest::MD5.hexdigest("#{entity.guid}|#{path.object_id}")
    end

  end

end