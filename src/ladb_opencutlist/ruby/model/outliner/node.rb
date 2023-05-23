module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Node

    include HashableHelper

    attr_accessor :name
    attr_reader :id, :nodes

    def initialize(id)
      @id = id
      @name = ''
      @nodes = []
    end

  end

end