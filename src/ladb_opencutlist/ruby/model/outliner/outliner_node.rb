module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../attributes/definition_attributes'

  class AbstractOutlinerNode

    include DefHelper
    include HashableHelper

    attr_reader :id, :entity_id, :type, :name, :default_name, :locked, :visible, :expanded, :part_count, :children

    def initialize(_def)
      @_def = _def

      @id = _def.id
      @entity_id = _def.entity_id
      @type = _def.type

      @name = _def.entity.name
      @default_name = _def.default_name

      @locked = false
      @visible = true
      @expanded = _def.expanded
      @part_count = _def.part_count

      @children = _def.children.map { |node_def| node_def.create_hashable }

    end

  end

  class OutlinerNodeModel < AbstractOutlinerNode

    attr_reader :description

    def initialize(_def)
      super

      @description = _def.entity.description

    end

  end

  class OutlinerNodeGroup < OutlinerNodeModel

    attr_reader :material, :layer

    def initialize(_def)
      super

      @locked = _def.entity.locked?
      @visible = _def.entity.visible?

      @material = _def.material_def ? _def.material_def.create_hashable : nil
      @layer = _def.layer_def ? _def.layer_def.create_hashable : nil

    end

  end

  class OutlinerNodeComponent < OutlinerNodeGroup

    attr_reader :definition_name, :description, :url, :tags

    def initialize(_def)
      super

      @definition_name = _def.entity.definition.name
      @description = _def.entity.definition.description

      definition_attributes = DefinitionAttributes.new(_def.entity.definition)
      @url = definition_attributes.url
      @tags = definition_attributes.tags

    end

  end

  class OutlinerNodePart < OutlinerNodeComponent

    def initialize(_def)
      super
    end

  end

end