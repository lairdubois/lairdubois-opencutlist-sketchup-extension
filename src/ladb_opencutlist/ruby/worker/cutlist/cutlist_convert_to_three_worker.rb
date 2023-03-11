module Ladb::OpenCutList

  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/axis_utils'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../lib/lgeom/transformation_helper'

  class CutlistConvertToThreeWorker

    include LayerVisibilityHelper

    def initialize(parts, all_instances = false, parts_colored = true)

      @parts = parts
      @all_instances = all_instances
      @parts_colored = parts_colored

    end

    # -----

    def run

      model = Sketchup.active_model
      return nil unless model

      materials = model.materials

      active_entity = model.active_path.nil? ? nil : model.active_path.last

      three_model_def = ThreeModelDef.new

      group_cache = {}  # key = serialized_path, value = group - Only for all instances

      @parts.each do |part|

        if @all_instances

          part.def.instance_infos.each { |serialized_path, instance_info|

            # Populate part definitions
            _create_three_part_def(three_model_def, part, instance_info.entity.definition, materials[part.material_name])

            # Create the three part instance def
            three_part_instance_def = ThreePartInstanceDef.new
            three_part_instance_def.matrix = _to_three_matrix(instance_info.entity.transformation)
            three_part_instance_def.id = part.id

            # Add to hierarchy
            parent_three_group_def = _parent_hierarchy(instance_info.path.slice(0, instance_info.path.length - 1), active_entity, group_cache, three_model_def)
            parent_three_group_def.add(three_part_instance_def)

            three_model_def.part_instance_count += 1

          }

        else

          # Extract first instance
          instance_info = part.def.instance_infos.values.first

          # Populate part definitions
          _create_three_part_def(three_model_def, part, instance_info.entity.definition, materials[part.material_name])

          # Retrieve axis order 0 = length axis, 1 = width axis, 2 = thickness axis
          axes_order = part.def.size.normals

          mt = Geom::Transformation.new
          if part.auto_oriented && part.group.material_type != MaterialAttributes::TYPE_HARDWARE

            # Set model matrix to put length axis along X, width along Y and thickness along Z to display the part always in the same direction even if it is auto oriented
            mt = Geom::Transformation.axes(ORIGIN, axes_order[0], axes_order[1], axes_order[2]).inverse
            three_model_def.matrix = _to_three_matrix(mt)

          end

          # Extract instance scale transformation
          it = instance_info.transformation
          it.extend(LGeom::TransformationHelper)
          ist = Geom::Transformation.scaling(it.x_scale, it.y_scale, it.z_scale)

          # Apply a rotation of 180° along length axis if part is flipped along thickness to force front face to be displayed on top
          if axes_order[2] == X_AXIS && it.x_scale < 0 || axes_order[2] == Y_AXIS && it.y_scale < 0 || axes_order[2] == Z_AXIS && it.z_scale < 0
            rt = Geom::Transformation.rotation(ORIGIN, axes_order[0], 180.degrees)
          else
            rt = Geom::Transformation.new
          end

          # Setup model axes matrix
          three_model_def.axes_matrix = _to_three_matrix(mt * ist * rt)

          # Create the three part instance def
          three_part_instance_def = ThreePartInstanceDef.new
          three_part_instance_def.matrix = _to_three_matrix(ist * rt)
          three_part_instance_def.id = part.id

          # Add to hierarchy
          three_model_def.add(three_part_instance_def)

          three_model_def.part_instance_count += 1

          # Extract bounding box dims
          unless part.group.material_type == MaterialAttributes::TYPE_HARDWARE
            three_model_def.x_dim = "#{Plugin.instance.get_i18n_string('tab.cutlist.list.length_short')} = #{part.length}"
            three_model_def.y_dim = "#{Plugin.instance.get_i18n_string('tab.cutlist.list.width_short')} = #{part.width}"
            three_model_def.z_dim = "#{Plugin.instance.get_i18n_string('tab.cutlist.list.thickness_short')} = #{part.thickness}"
          end

        end

      end

      # _dump(three_model_def)

      three_model_def
    end

    # -----

    def _create_three_part_def(three_model_def, part, definition, material)

      three_part_def = three_model_def.part_defs.fetch(part.id, nil)
      if three_part_def.nil?

        three_part_def = ThreePartDef.new
        three_part_def.face_vertices,
        three_part_def.face_colors,
        three_part_def.hard_edge_vertices,
        three_part_def.soft_edge_vertices,
        three_part_def.soft_edge_controls0,
        three_part_def.soft_edge_controls1,
        three_part_def.soft_edge_directions = _grab_entities_vertices_and_colors(definition.entities, material)
        three_part_def.name = part.name
        three_part_def.number = part.number
        three_part_def.color = _to_three_color(material)

        three_model_def.part_defs.store(part.id, three_part_def)
      end

    end

    def _grab_entities_vertices_and_colors(entities, material, transformation = nil)
      face_vertices = []
      face_colors = []
      hard_edge_vertices = []
      soft_edge_vertices = []
      soft_edge_controls0 = []
      soft_edge_controls1 = []
      soft_edge_directions = []
      entities.each do |entity|

        next unless entity.visible? && _layer_visible?(entity.layer)

        if entity.is_a?(Sketchup::Face)
          fv, fc = _grab_face_vertices_and_colors(entity, material, transformation)
          face_vertices.concat(fv)
          face_colors.concat(fc)
        elsif entity.is_a?(Sketchup::Edge)
          hev, sev, sec0, sec1, dir = _grab_edge_vertices_and_controls(entity, transformation)
          hard_edge_vertices.concat(hev)
          soft_edge_vertices.concat(sev)
          soft_edge_controls0.concat(sec0)
          soft_edge_controls1.concat(sec1)
          soft_edge_directions.concat(dir)
        elsif entity.is_a?(Sketchup::Group)
          fv, fc, hev, sev, sec0, sec1, dir = _grab_entities_vertices_and_colors(entity.entities, entity.material.nil? ? material : entity.material, TransformationUtils::multiply(transformation, entity.transformation))
          face_vertices.concat(fv)
          face_colors.concat(fc)
          hard_edge_vertices.concat(hev)
          soft_edge_vertices.concat(sev)
          soft_edge_controls0.concat(sec0)
          soft_edge_controls1.concat(sec1)
          soft_edge_directions.concat(dir)
        elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
          fv, fc, hev, sev, sec0, sec1, dir = _grab_entities_vertices_and_colors(entity.definition.entities, entity.material.nil? ? material : entity.material, TransformationUtils::multiply(transformation, entity.transformation))
          face_vertices.concat(fv)
          face_colors.concat(fc)
          hard_edge_vertices.concat(hev)
          soft_edge_vertices.concat(sev)
          soft_edge_controls0.concat(sec0)
          soft_edge_controls1.concat(sec1)
          soft_edge_directions.concat(dir)
        end

      end

      [ face_vertices, face_colors, hard_edge_vertices, soft_edge_vertices, soft_edge_controls0, soft_edge_controls1, soft_edge_directions ]
    end

    def _grab_face_vertices_and_colors(face, material, transformation = nil)

      mesh = face.mesh(0) # POLYGON_MESH_POINTS
      points = mesh.points

      red, green, blue = _to_three_vertex_color(face.material.nil? ? material : face.material)

      Point3dUtils::transform_points(points, transformation)

      vertices = []
      colors = []
      mesh.polygons.each { |polygon|
        polygon.each { |index|

          point = points[index.abs - 1]
          vertices << point.x.to_f
          vertices << point.y.to_f
          vertices << point.z.to_f

          if @parts_colored
            colors << red
            colors << green
            colors << blue
          end

        }
      }

      [ vertices, colors ]
    end

    def _grab_edge_vertices_and_controls(edge, transformation = nil)
      hard_vertices = []
      soft_vertices = []
      soft_controls0 = []
      soft_controls1 = []
      soft_directions = []

      unless edge.faces.empty?  # Exclude edges not connected to a face

        # Soft controls
        if edge.soft?

          edge.faces.each do |face|

            vertex = face.vertices.find { |v| !edge.used_by?(v) }
            if vertex.is_a?(Sketchup::Vertex)

              point = vertex.position
              point.transform!(transformation) unless transformation.nil?

              # Inspired from LDraw specification : https://www.ldraw.org/article/218.html#lt5
              controls = soft_controls0.empty? ? soft_controls0 : soft_controls1
              2.times do
                controls << point.x.to_f
                controls << point.y.to_f
                controls << point.z.to_f
              end

            end

            unless soft_controls0.empty? || soft_controls1.empty?
              break
            end

          end

          # Check if there's enough controls
          if soft_controls0.empty? || soft_controls1.empty?
            soft_controls0.clear
            soft_controls1.clear
          end

        end

        # Vertices
        edge.vertices.each do |vertex|

          point = vertex.position
          point.transform!(transformation) unless transformation.nil?

          vertices = soft_controls0.empty? ? hard_vertices : soft_vertices
          vertices << point.x.to_f
          vertices << point.y.to_f
          vertices << point.z.to_f

        end

        # Soft directions
        unless soft_controls0.empty?
          2.times do
            soft_directions << soft_vertices[3] - soft_vertices[0]
            soft_directions << soft_vertices[4] - soft_vertices[1]
            soft_directions << soft_vertices[5] - soft_vertices[2]
          end
        end

      end

      [ hard_vertices, soft_vertices, soft_controls0, soft_controls1, soft_directions ]
    end

    def _parent_hierarchy(path, active_entity, cache, three_model_def)
      return three_model_def if path.nil? || path.empty?
      return three_model_def if path.last == active_entity

      serialized_path = PathUtils.serialize_path(path)

      # Pop last path entity
      entity = path.pop

      # Try to fetch three group def from cache
      three_group_def = cache.fetch(serialized_path, nil)
      unless three_group_def

        # Create a new three group def
        three_group_def = ThreeGroupDef.new
        three_group_def.name = entity.name
        three_group_def.matrix = _to_three_matrix(entity.transformation)

        # Keep it in the cache
        cache.store(serialized_path, three_group_def)

        # Try to retrieve parent
        parent_three_group_def = _parent_hierarchy(path, active_entity, cache, three_model_def)
        if parent_three_group_def
          # Parent found, add current group as child
          parent_three_group_def.add(three_group_def)
        else
          # No more parent, add current group to model
          three_model_def.add(three_group_def)
        end

      end

      three_group_def
    end

    def _to_three_matrix(tranformation)
      return nil unless tranformation.is_a?(Geom::Transformation)
      # return nil if tranformation.identity?
      tranformation.to_a.flatten
    end

    def _to_three_color(material)
      return nil unless material.is_a?(Sketchup::Material)
      (material.color.red << 16) + (material.color.green << 8) + material.color.blue
    end

    def _to_three_vertex_color(material)
      return [ 1, 1, 1 ] unless material.is_a?(Sketchup::Material)
      [ material.color.red / 255.0, material.color.green / 255.0, material.color.blue / 255.0 ]
    end

    def _dump(three_object_def, level = 1)
      puts "#{'+'.rjust(level, '-')}#{three_object_def.class.to_s} #{three_object_def.name} #{(three_object_def.is_a?(ThreePartInstanceDef) ? three_object_def.id.to_s : '')}"
      if three_object_def.is_a?(ThreeModelDef)
        three_object_def.part_defs.each do |id, part_def|
          puts "@ #{id} - (#{part_def.number}) #{part_def.name}"
        end
      end
      if three_object_def.is_a?(ThreeGroupDef)
        _dump_matrix(three_object_def.matrix, level)
        three_object_def.children.each do |child_three_object_def|
          _dump(child_three_object_def, level + 1)
        end
      end
    end

    def _dump_matrix(matrix, level)
      matrix = _to_three_matrix(Geom::Transformation.new) if matrix.nil?
      puts "#{'+'.rjust(level, ' ')} #{matrix[0].round(1)} #{matrix[4].round(1)} #{matrix[8].round(1)} #{matrix[12].round(1)}"
      puts "#{'+'.rjust(level, ' ')} #{matrix[1].round(1)} #{matrix[5].round(1)} #{matrix[9].round(1)} #{matrix[13].round(1)}"
      puts "#{'+'.rjust(level, ' ')} #{matrix[2].round(1)} #{matrix[6].round(1)} #{matrix[10].round(1)} #{matrix[14].round(1)}"
      puts "#{'+'.rjust(level, ' ')} #{matrix[3].round(1)} #{matrix[7].round(1)} #{matrix[11].round(1)} #{matrix[15].round(1)}"
    end

  end

  # -----

  class ThreePartDef

    include HashableHelper

    attr_accessor :face_vertices, :face_colors, :hard_edge_vertices, :soft_edge_vertices, :soft_edge_controls0, :soft_edge_controls1, :soft_edge_directions, :name, :number, :color, :pin_text, :pin_class, :pin_color

    def initialize
      @face_vertices = []
      @face_colors = []
      @hard_edge_vertices = []
      @soft_edge_vertices = []
      @soft_edge_controls0 = []
      @soft_edge_controls1 = []
      @soft_edge_directions = []
      @name = nil
      @number = nil
      @color = nil
      @pin_text = nil
      @pin_class = nil
      @pin_color = nil
    end

  end

  class ThreeObjectDef

    include HashableHelper

    TYPE_UNDEFINED = 0
    TYPE_MODEL = 1
    TYPE_GROUP = 2
    TYPE_PART_INSTANCE = 3

    attr_accessor :name

    def initialize(type = TYPE_UNDEFINED)
      @type = type
      @name = ''
    end

    def type
      @type
    end

  end

  class ThreeGroupDef < ThreeObjectDef

    attr_accessor :matrix
    attr_reader :children

    def initialize(type = ThreeObjectDef::TYPE_GROUP)
      super(type)
      @matrix = nil
      @children = []
    end

    def add(three_object)
      @children.push(three_object)
    end

  end

  class ThreeModelDef < ThreeGroupDef

    attr_accessor :part_instance_count, :axes_matrix, :x_dim, :y_dim, :z_dim
    attr_reader :part_defs

    def initialize
      super(ThreeObjectDef::TYPE_MODEL)
      @part_defs = {}
      @part_instance_count = 0
      @axes_matrix = nil
      @x_dim = nil
      @y_dim = nil
      @z_dim = nil
    end

  end

  class ThreePartInstanceDef < ThreeGroupDef

    attr_accessor :id

    def initialize
      super(ThreeObjectDef::TYPE_PART_INSTANCE)
      @id = nil
    end

  end

end