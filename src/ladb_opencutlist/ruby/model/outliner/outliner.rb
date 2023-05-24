module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Outliner

    include HashableHelper

    attr_accessor :root_node
    attr_reader :errors, :warnings, :tips, :filename, :model_name

    def initialize(filename, model_name)
      @_obsolete = false
      @_observers = []

      @errors = []
      @warnings = []
      @tips = []

      @filename = filename
      @model_name = model_name

      @root_node = nil

    end

    # ---

    def invalidate
      @_obsolete = true
      _fire_invalidate_event
    end

    def obsolete?
      @_obsolete
    end

    # Errors

    def add_error(error)
      @errors.push(error)
    end

    # Warnings

    def add_warning(warning)
      @warnings.push(warning)
    end

    # Tips

    def add_tip(tip)
      @tips.push(tip)
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
