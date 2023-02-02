module Ladb::OpenCutList

  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../helper/hashable_helper'

  class CutlistGetThumbnailWorker

    include LayerVisibilityHelper

    def initialize(part_data, cutlist)

      @definition_id = part_data.fetch('definition_id')
      @id = part_data.fetch('id')

      @cutlist = cutlist

    end

    # -----

    def run
      response = {
          :thumbnail_file => ''
      }

      model = Sketchup.active_model
      return response unless model

      definitions = model.definitions
      definition = definitions[@definition_id]
      if definition

        ##

        part = @cutlist.get_part(@id)

        three_object_def = ThreeGroupDef.new

        _populate_three_object_def(three_object_def, definition)

        three_object_def.matrix = _to_three_matrix(Geom::Transformation.scaling(part.def.scale.x * (part.flipped ? -1 : 1), part.def.scale.y, part.def.scale.z))
        three_object_def.color = _to_three_color(model.materials[part.material_name])

        response[:three_object_def] = three_object_def.to_hash

        ##


        temp_dir = Plugin.instance.temp_dir
        component_thumbnails_dir = File.join(temp_dir, 'components_thumbnails')
        unless Dir.exist?(component_thumbnails_dir)
          Dir.mkdir(component_thumbnails_dir)
        end

        thumbnail_file = File.join(component_thumbnails_dir, "#{definition.guid}.png")
        definition.save_thumbnail(thumbnail_file)

        response[:thumbnail_file] = thumbnail_file
      end

      response
    end

    # -----

    def _populate_three_object_def(three_object_def, entity)
      return if entity.is_a?(Sketchup::Edge)   # Minor Speed imrovement when there's a lot of edges

      if entity.is_a?(Sketchup::Face)

        return unless entity.visible? && _layer_visible?(entity.layer)

        three_mesh_def = ThreeMeshDef.new
        three_mesh_def.color = _to_three_color(entity.material)
        three_mesh_def.vertices = entity.mesh.polygons.map { |polygon|
          polygon.map { |index|
            point = entity.mesh.point_at(index)
            [ point.x.to_f, point.y.to_f, point.z.to_f ]
          }.flatten
        }.flatten

        three_object_def.add(three_mesh_def)

      elsif entity.is_a?(Sketchup::Group)

        return unless entity.visible? && _layer_visible?(entity.layer)

        three_group_def = ThreeGroupDef.new
        three_group_def.matrix = _to_three_matrix(entity.transformation)
        three_group_def.color = _to_three_color(entity.material)

        three_object_def.add(three_group_def)

        entity.entities.each do |child_entity|
          _populate_three_object_def(three_group_def, child_entity)
        end

      elsif entity.is_a?(Sketchup::ComponentInstance)

        return unless entity.visible? && _layer_visible?(entity.layer)

        three_group_def = ThreeGroupDef.new
        three_group_def.matrix = _to_three_matrix(entity.transformation)
        three_group_def.color = _to_three_color(entity.material)

        three_object_def.add(three_group_def)

        entity.definition.entities.each do |child_entity|
          _populate_three_object_def(three_group_def, child_entity)
        end

      elsif entity.is_a?(Sketchup::ComponentDefinition)

        entity.entities.each do |child_entity|
          _populate_three_object_def(three_object_def, child_entity)
        end

      elsif entity.is_a?(Sketchup::Model)

        entity.entities.each do |child_entity|
          _populate_three_object_def(three_object_def, child_entity)
        end

      end

    end

    def _to_three_matrix(tranformation)
      return nil unless tranformation.is_a?(Geom::Transformation)
      return nil if tranformation.identity?
      tranformation.to_a.flatten
    end

    def _to_three_color(material)
      return nil unless material.is_a?(Sketchup::Material)
      (material.color.red << 16) + (material.color.green << 8) + material.color.blue
    end

  end

  class ThreeObjectDef

    include HashableHelper

    TYPE_UNDEFINED = 0
    TYPE_GROUP = 1
    TYPE_MESH = 2

    attr_accessor :color

    def initialize(type = TYPE_UNDEFINED)
      @type = type
      @color = nil
    end

    def type
      @type
    end

  end

  class ThreeGroupDef < ThreeObjectDef

    attr_accessor :matrix
    attr_reader :children

    def initialize
      super(ThreeObjectDef::TYPE_GROUP)
      @matrix = nil
      @children = []
    end

    def add(three_object)
      @children.push(three_object)
    end

  end

  class ThreeMeshDef < ThreeObjectDef

    attr_accessor :vertices

    def initialize
      super(ThreeObjectDef::TYPE_MESH)
      @vertices = []
    end

  end

end