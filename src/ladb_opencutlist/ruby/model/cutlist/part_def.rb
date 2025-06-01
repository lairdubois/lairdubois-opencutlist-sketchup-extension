module Ladb::OpenCutList

  require 'digest'
  require_relative '../data_container'

  class PartDef < DataContainer

    EDGES_Y = [ :ymin, :ymax ]
    EDGES_X = [ :xmin, :xmax ]

    VENEERS_Z = [ :zmin, :zmax ]

    attr_accessor :id, :definition_id, :number, :saved_number, :name, :is_dynamic_attributes_name, :description, :url, :count, :cutting_size, :size, :scale, :flipped, :material_name, :material_origins, :cumulable, :instance_count_by_part, :mass, :price, :thickness_layer_count, :orientation_locked_on_axis, :tags, :symmetrical, :ignore_grain_direction, :length_increase, :width_increase, :thickness_increase, :edge_count, :edge_pattern, :edge_entity_ids, :edge_length_decrement, :edge_width_decrement, :edge_decremented, :face_count, :face_pattern, :face_entity_ids, :face_texture_angles, :face_thickness_decrement, :face_decremented, :length_increased, :width_increased, :thickness_increased, :auto_oriented, :not_aligned_on_axes, :unused_instance_count, :content_layers, :final_area, :children_warning_count, :children_length_increased_count, :children_width_increased_count, :children_thickness_increased_count
    attr_reader :id, :virtual, :edge_material_names, :edge_material_colors, :edge_std_dimensions, :edge_errors, :face_material_names, :face_material_colors, :face_std_dimensions, :face_errors, :entity_ids, :entity_serialized_paths, :entity_names, :children, :instance_infos, :edge_materials, :edge_group_defs, :veneer_materials, :veneer_group_defs, :drawing_defs

    def initialize(id, virtual = false)
      @id = id
      @virtual = virtual
      @definition_id = nil
      @number = nil
      @saved_number = nil
      @name = ''
      @is_dynamic_attributes_name = false
      @description = ''
      @url = ''
      @count = 0
      @cutting_size = Size3d.new
      @size = Size3d.new
      @scale = Scale3d.new
      @flipped = false
      @material_name = ''
      @material_origins = []
      @cumulable = DefinitionAttributes::CUMULABLE_NONE
      @instance_count_by_part = 1
      @mass = ''
      @price = ''
      @thickness_layer_count = 1
      @tags = []
      @orientation_locked_on_axis = false
      @symmetrical = false
      @ignore_grain_direction = false
      @length_increase = 0
      @width_increase = 0
      @thickness_increase = 0
      @edge_count = 0
      @edge_pattern = nil                 # A string from 0000 to 1111
      @edge_material_names = {}
      @edge_material_colors = {}
      @edge_std_dimensions = {}
      @edge_length_decrement = 0
      @edge_width_decrement = 0
      @edge_decremented = false
      @edge_entity_ids = {}
      @edge_errors = []
      @face_count = 0
      @face_pattern = nil                 # A string from 00 to 11
      @face_material_names = {}
      @face_material_colors = {}
      @face_std_dimensions = {}
      @face_thickness_decrement = 0
      @face_decremented = false
      @face_entity_ids = {}
      @face_texture_angles = {}
      @face_errors = []
      @entity_ids = []                    # All unique entity ids (array count could be smaller than @count)
      @entity_serialized_paths = []       # All Serialized paths to each entity (array count should be egals to @count)
      @entity_names = {}                  # All non empty entity instance names (key = name, value = array of 'named path')
      @length_increased = false
      @width_increased = false
      @thickness_increased = false
      @auto_oriented = false
      @not_aligned_on_axes = false
      @unused_instance_count = 0
      @content_layers = []
      @final_area = 0

      @children_warning_count = 0
      @children_length_increased_count = 0
      @children_width_increased_count = 0
      @children_thickness_increased_count = 0
      @children = []

      # Internal
      @instance_infos = {}
      @edge_materials = {}
      @edge_group_defs = {}
      @veneer_materials = {}
      @veneer_group_defs = {}

      @drawing_defs = {}  # Cache for drawing defs, Key = PART_DRAWING_TYPE_XX

    end

    # -----

    def self.generate_part_id(group_id, definition, definition_attributes, instance_info, dynamic_attributes_name = false, flipped_detection = true)

      # Uses name for dynamic components to separate instances with the same definition, but different name
      entity_id = definition_attributes.uuid.nil? ? definition.entityID : definition_attributes.uuid
      if dynamic_attributes_name
        name, is_dynamic_attributes_name = instance_info.read_name(dynamic_attributes_name)
        entity_id = "#{entity_id}|#{name}" if is_dynamic_attributes_name
      end

      # Include scale in part_id to separate instances with the same definition, but different scale
      Digest::MD5.hexdigest("#{group_id}|#{entity_id}|#{DimensionUtils.to_ocl_precision_f(instance_info.size.length).to_s}|#{DimensionUtils.to_ocl_precision_f(instance_info.size.width).to_s}|#{DimensionUtils.to_ocl_precision_f(instance_info.size.thickness).to_s}|#{flipped_detection && (definition_attributes.symmetrical ? false : instance_info.flipped)}")

    end

    def self.generate_edge_part_id(group_id, part_id, edge, length, width, thickness)
      Digest::MD5.hexdigest("#{group_id}|#{part_id}|#{edge}|#{length}|#{width}|#{thickness}")
    end

    def self.generate_veneer_part_id(group_id, part_id, veneer, length, width, thickness)
      Digest::MD5.hexdigest("#{group_id}|#{part_id}|#{veneer}|#{length}|#{width}|#{thickness}")
    end

    def self.part_order(part_def_a, part_def_b, strategy)
      a_values = []
      b_values = []
      if strategy
        properties = strategy.split('>')
        properties.each { |property|
          next if property.length < 1
          asc = true
          if property.start_with?('-')
            asc = false
            property.slice!(0)
          end
          case property
            when 'length'
              a_value = [ part_def_a.cumulative_cutting_length ]
              b_value = [ part_def_b.cumulative_cutting_length ]
            when 'width'
              a_value = [ part_def_a.cumulative_cutting_width ]
              b_value = [ part_def_b.cumulative_cutting_width ]
            when 'thickness'
              a_value = [ part_def_a.size.thickness ]
              b_value = [ part_def_b.size.thickness ]
            when 'name'
              a_value = [ part_def_a.name.downcase ]
              b_value = [ part_def_b.name.downcase ]
            when 'count'
              a_value = [ part_def_a.count ]
              b_value = [ part_def_b.count ]
            when 'edge_pattern'
              a_value = [ part_def_a.edge_count, part_def_a.edge_pattern.nil? ? '' : part_def_a.edge_pattern ]
              b_value = [ part_def_b.edge_count, part_def_b.edge_pattern.nil? ? '' : part_def_b.edge_pattern ]
            when 'tags'
              a_value = [ part_def_a.tags ]
              b_value = [ part_def_b.tags ]
            when 'thickness_layer_count'
              a_value = [ part_def_a.thickness_layer_count ]
              b_value = [ part_def_b.thickness_layer_count ]
            else
              next
          end
          if asc
            a_values.concat(a_value)
            b_values.concat(b_value)
          else
            a_values.concat(b_value)
            b_values.concat(a_value)
          end
        }
      end
      result = a_values <=> b_values
      if result == 0

        # In the case of equality, add an extra compare on part flipped ASC
        a_values << (part_def_a.flipped ? 1 : 0)
        b_values << (part_def_b.flipped ? 1 : 0)
        result = a_values <=> b_values

      end
      result
    end

    # -----

    def definition
      return nil if Sketchup.active_model.nil? || @definition_id.nil?
      Sketchup.active_model.definitions[@definition_id]
    end

    # -----

    # InstanceInfos

    def store_instance_info(instance_info)
      @instance_infos[instance_info.serialized_path] = instance_info
    end

    def get_instance_info(serialized_path)
      if @instance_infos.has_key? serialized_path
        return @instance_infos[serialized_path]
      end
      nil
    end

    def get_one_instance_info
      @instance_infos.values.first
    end

    # ---

    def cutting_length
      @cutting_size.length == @size.length && @edge_length_decrement ? edge_cutting_length : @cutting_size.length
    end

    def cutting_width
      @cutting_size.width == @size.width && @edge_width_decrement ? edge_cutting_width : @cutting_size.width
    end

    def edge_cutting_length
      [@size.length - @edge_length_decrement, 0].max.to_l
    end

    def edge_cutting_width
      [@size.width - @edge_width_decrement, 0].max.to_l
    end

    def cumulative_cutting_length
      if @count > 1 && @cumulable == DefinitionAttributes::CUMULABLE_LENGTH
        (@cutting_size.length.to_f * @count).to_l
      else
        @cutting_size.length
      end
    end

    def cumulative_cutting_width
      if @count > 1 && @cumulable == DefinitionAttributes::CUMULABLE_WIDTH
        (@cutting_size.width.to_f * @count).to_l
      else
        @cutting_size.width
      end
    end

    def add_material_origin(material_origin)
      unless @material_origins.include?(material_origin)
        @material_origins.push(material_origin)
      end
    end

    def add_entity_id(entity_id)
      unless @entity_ids.include?(entity_id)   # Because of groups and components, multiple entity can have the same ID
        @entity_ids.push(entity_id)
      end
    end

    def add_entity_serialized_path(entity_serialized_path)
      @entity_serialized_paths.push(entity_serialized_path)
    end

    def add_entity_name(entity_name, entity_named_path)
      if @entity_names.has_key?(entity_name)
        @entity_names[entity_name].push(entity_named_path)
      else
        @entity_names[entity_name] = [ entity_named_path ]
      end
    end

    def merge_entity_names(entity_names)
      entity_names.each { |entity_name, entity_named_paths|
        entity_named_paths.each { |entity_named_path|
          add_entity_name(entity_name, entity_named_path)
        }
      }
    end

    def multiple_content_layers
      @content_layers.length > 1
    end

    def set_edge_materials(edge_ymin_material, edge_ymax_material, edge_xmin_material, edge_xmax_material)

      # Store materials internaly
      @edge_materials.store(:ymin, edge_ymin_material) unless edge_ymin_material.nil?
      @edge_materials.store(:ymax, edge_ymax_material) unless edge_ymax_material.nil?
      @edge_materials.store(:xmin, edge_xmin_material) unless edge_xmin_material.nil?
      @edge_materials.store(:xmax, edge_xmax_material) unless edge_xmax_material.nil?

      # Store material names
      @edge_material_names.store(:ymin, edge_ymin_material.name) unless edge_ymin_material.nil?
      @edge_material_names.store(:ymax, edge_ymax_material.name) unless edge_ymax_material.nil?
      @edge_material_names.store(:xmin, edge_xmin_material.name) unless edge_xmin_material.nil?
      @edge_material_names.store(:xmax, edge_xmax_material.name) unless edge_xmax_material.nil?

      # Store material colors
      @edge_material_colors.store(:ymin, edge_ymin_material.color) unless edge_ymin_material.nil?
      @edge_material_colors.store(:ymax, edge_ymax_material.color) unless edge_ymax_material.nil?
      @edge_material_colors.store(:xmin, edge_xmin_material.color) unless edge_xmin_material.nil?
      @edge_material_colors.store(:xmax, edge_xmax_material.color) unless edge_xmax_material.nil?

      # Compute edge count
      @edge_count = [ edge_ymin_material, edge_ymax_material, edge_xmin_material, edge_xmax_material ].compact.length

      # Build edge pattern
      @edge_pattern = "#{edge_ymax_material ? 1 : 0}#{edge_xmax_material ? 1 : 0}#{edge_ymin_material ? 1 : 0}#{edge_xmin_material ? 1 : 0}"

    end

    def set_edge_entity_ids(edge_ymin_entity_ids, edge_ymax_entity_ids, edge_xmin_entity_ids, edge_xmax_entity_ids)

      # Store materials internaly
      @edge_entity_ids.store(:ymin, edge_ymin_entity_ids) unless edge_ymin_entity_ids.nil?
      @edge_entity_ids.store(:ymax, edge_ymax_entity_ids) unless edge_ymax_entity_ids.nil?
      @edge_entity_ids.store(:xmin, edge_xmin_entity_ids) unless edge_xmin_entity_ids.nil?
      @edge_entity_ids.store(:xmax, edge_xmax_entity_ids) unless edge_xmax_entity_ids.nil?

    end

    def set_edge_group_defs(edge_ymin_group_def, edge_ymax_group_def, edge_xmin_group_def, edge_xmax_group_def)

      # Store groupDefs internaly
      @edge_group_defs.store(:ymin, edge_ymin_group_def) unless edge_ymin_group_def.nil?
      @edge_group_defs.store(:ymax, edge_ymax_group_def) unless edge_ymax_group_def.nil?
      @edge_group_defs.store(:xmin, edge_xmin_group_def) unless edge_xmin_group_def.nil?
      @edge_group_defs.store(:xmax, edge_xmax_group_def) unless edge_xmax_group_def.nil?

      # Store stdDimensions
      @edge_std_dimensions.store(:ymin, "#{edge_ymin_group_def.std_thickness} x #{edge_ymin_group_def.std_dimension}") unless edge_ymin_group_def.nil?
      @edge_std_dimensions.store(:ymax, "#{edge_ymax_group_def.std_thickness} x #{edge_ymax_group_def.std_dimension}") unless edge_ymax_group_def.nil?
      @edge_std_dimensions.store(:xmin, "#{edge_xmin_group_def.std_thickness} x #{edge_xmin_group_def.std_dimension}") unless edge_xmin_group_def.nil?
      @edge_std_dimensions.store(:xmax, "#{edge_xmax_group_def.std_thickness} x #{edge_xmax_group_def.std_dimension}") unless edge_xmax_group_def.nil?

    end

    def set_veneer_materials(veneer_zmin_material, veneer_zmax_material)

      # Store materials internaly
      @veneer_materials.store(:zmin, veneer_zmin_material) unless veneer_zmin_material.nil?
      @veneer_materials.store(:zmax, veneer_zmax_material) unless veneer_zmax_material.nil?

      # Store material names
      @face_material_names.store(:zmin, veneer_zmin_material.name) unless veneer_zmin_material.nil?
      @face_material_names.store(:zmax, veneer_zmax_material.name) unless veneer_zmax_material.nil?

      # Store material colors
      @face_material_colors.store(:zmin, veneer_zmin_material.color) unless veneer_zmin_material.nil?
      @face_material_colors.store(:zmax, veneer_zmax_material.color) unless veneer_zmax_material.nil?

      # Compute face count
      @face_count = [veneer_zmin_material, veneer_zmax_material ].compact.length

      # Bluid face pattern
      @face_pattern = "#{veneer_zmax_material ? 1 : 0}#{veneer_zmin_material ? 1 : 0}"

    end

    def set_veneer_entity_ids(veneer_zmin_entity_ids, veneer_zmax_entity_ids)

      # Store materials internaly
      @face_entity_ids.store(:zmin, veneer_zmin_entity_ids) unless veneer_zmin_entity_ids.nil?
      @face_entity_ids.store(:zmax, veneer_zmax_entity_ids) unless veneer_zmax_entity_ids.nil?

    end

    def set_veneer_texture_angles(veneer_zmin_texture_angles, veneer_zmax_texture_angles)

      # Store materials internaly
      @face_texture_angles.store(:zmin, veneer_zmin_texture_angles) unless veneer_zmin_texture_angles.nil?
      @face_texture_angles.store(:zmax, veneer_zmax_texture_angles) unless veneer_zmax_texture_angles.nil?

    end

    def set_veneer_group_defs(veneer_zmin_group_def, veneer_zmax_group_def)

      # Store groupDefs internaly
      @veneer_group_defs.store(:zmin, veneer_zmin_group_def) unless veneer_zmin_group_def.nil?
      @veneer_group_defs.store(:zmax, veneer_zmax_group_def) unless veneer_zmax_group_def.nil?

      # Store stdDimensions
      @face_std_dimensions.store(:zmin, "#{veneer_zmin_group_def.std_dimension}") unless veneer_zmin_group_def.nil?
      @face_std_dimensions.store(:zmax, "#{veneer_zmax_group_def.std_dimension}") unless veneer_zmax_group_def.nil?

    end

  end

end