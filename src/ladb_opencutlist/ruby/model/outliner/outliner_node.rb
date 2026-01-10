module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../attributes/definition_attributes'

  class OutlinerNode < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :id, :depth, :type,
                :name, :default_name,
                :locked, :computed_locked, :visible, :computed_visible, :expanded, :expandable, :child_active, :active, :selected,
                :children

    def initialize(_def)
      @_def = _def

      @id = _def.id
      @depth = _def.depth
      @type = _def.type

      @name = _def.name
      @default_name = _def.default_name

      @locked = _def.locked?
      @computed_locked = _def.computed_locked?
      @visible = _def.visible?
      @computed_visible = _def.computed_visible?
      @expanded = _def.expanded
      @expandable = _def.expandable?
      @child_active = _def.child_active
      @active = _def.active
      @selected = _def.selected

      @children = _def.expanded || _def.child_active || _def.active ? _def.children.select { |node_def| !node_def.entity.deleted? }.map { |node_def| node_def.get_hashable } : []

    end

  end

  class OutlinerNodeModel < OutlinerNode

    attr_reader :description

    def initialize(_def)
      super

      @description = _def.entity.description

    end

  end

  class OutlinerNodeGroup < OutlinerNode

    attr_reader :material, :layer,
                :is2d, :snapto, :cuts_opening, :always_face_camera, :shadows_face_sun, :no_scale_mask

    def initialize(_def)
      super

      @material = _def.material_def ? _def.material_def.get_hashable : nil
      @layer = _def.layer_def ? _def.layer_def.get_hashable : nil

      @is2d = _def.is2d?
      @snapto = _def.snapto
      @always_face_camera = _def.always_face_camera?
      @cuts_opening = _def.cuts_opening?
      @shadows_face_sun = _def.shadows_face_sun?
      @no_scale_mask = _def.no_scale_mask?

    end

  end

  class OutlinerNodeComponent < OutlinerNodeGroup

    attr_reader :definition_name, :description,
                :live_component,
                :url, :tags

    def initialize(_def)
      super

      @default_name = _def.default_name
      @definition_name = _def.definition_name
      @description = _def.description

      @live_component = _def.live_component?

      definition_attributes = DefinitionAttributes.new(_def.entity.definition)
      @url = definition_attributes.url
      @tags = definition_attributes.tags

    end

  end

end