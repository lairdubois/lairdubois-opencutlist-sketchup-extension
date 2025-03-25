module Ladb::OpenCutList

  require 'json'
  require 'cgi'
  require 'securerandom'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../helper/material_attributes_caching_helper'
  require_relative '../../helper/estimation_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/packy/packy'
  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../model/packing/packing_def'
  require_relative '../../model/export/wrappers'

  class AbstractCutlistPackingWorker

    Packy = Fiddle::Packy

    ORIGIN_CORNER_TOP_LEFT = 0
    ORIGIN_CORNER_BOTTOM_LEFT = 1
    ORIGIN_CORNER_TOP_RIGHT = 2
    ORIGIN_CORNER_BOTTOM_RIGHT = 3

    protected

    # -----

    def _compute_item_bounds_in_bin_space(item_length, item_width, item_def)
      t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, item_def.angle.degrees)
      t *= Geom::Transformation.scaling(-1.0, 1.0, 1.0) if item_def.mirror
      Geom::BoundingBox.new.add(
        [
          Geom::Point3d.new(0, 0),
          Geom::Point3d.new(item_length, 0),
          Geom::Point3d.new(item_length, item_width),
          Geom::Point3d.new(0, item_width),
        ].each { |pt| pt.transform!(t) }
      )
    end

    # -----

    def _compute_x_with_origin_corner(problem_type, origin_corner, x, x_size, x_translation)
      return x if problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      case origin_corner
      when ORIGIN_CORNER_TOP_RIGHT, ORIGIN_CORNER_BOTTOM_RIGHT
        x_translation - x - x_size
      else
        x
      end
    end

    def _compute_y_with_origin_corner(problem_type, origin_corner, y, y_size, y_translation)
      return y if problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      case origin_corner
      when ORIGIN_CORNER_TOP_LEFT, ORIGIN_CORNER_TOP_RIGHT
        y_translation - y - y_size
      else
        y
      end
    end

    # -----

    def _evaluate_item_text(formula, part, instance_info)

      data = PackingData.new(

        number: StringWrapper.new(part.number),
        path: instance_info.nil? ? nil : PathWrapper.new(instance_info.named_path.split('.')),
        instance_name: instance_info.nil? ? nil : StringWrapper.new(instance_info.entity.name),
        name: StringWrapper.new(part.name),
        cutting_length: LengthWrapper.new(part.def.cutting_length),
        cutting_width: LengthWrapper.new(part.def.cutting_width),
        cutting_thickness: LengthWrapper.new(part.def.cutting_size.thickness),
        edge_cutting_length: LengthWrapper.new(part.def.edge_cutting_length),
        edge_cutting_width: LengthWrapper.new(part.def.edge_cutting_width),
        bbox_length: LengthWrapper.new(part.def.size.length),
        bbox_width: LengthWrapper.new(part.def.size.width),
        bbox_thickness: LengthWrapper.new(part.def.size.thickness),
        final_area: AreaWrapper.new(part.def.final_area),
        material: MaterialWrapper.new(part.group.def.material, part.group.def),
        description: StringWrapper.new(part.description),
        url: StringWrapper.new(part.url),
        tags: ArrayWrapper.new(part.tags),
        edge_ymin: EdgeWrapper.new(part.def.edge_materials[:ymin], part.def.edge_group_defs[:ymin]),
        edge_ymax: EdgeWrapper.new(part.def.edge_materials[:ymax], part.def.edge_group_defs[:ymax]),
        edge_xmin: EdgeWrapper.new(part.def.edge_materials[:xmin], part.def.edge_group_defs[:xmin]),
        edge_xmax: EdgeWrapper.new(part.def.edge_materials[:xmax], part.def.edge_group_defs[:xmax]),
        face_zmin: VeneerWrapper.new(part.def.veneer_materials[:zmin], part.def.veneer_group_defs[:zmin]),
        face_zmax: VeneerWrapper.new(part.def.veneer_materials[:zmax], part.def.veneer_group_defs[:zmax]),
        layer: instance_info.nil? ? nil : StringWrapper.new(instance_info.layer.name),

        component_definition: ComponentDefinitionWrapper.new(part.def.definition),
        component_instance: instance_info.nil? ? nil : ComponentInstanceWrapper.new(instance_info.entity),

        )

      begin
        text = eval(formula, data.get_binding)
        text = text.export if text.is_a?(Wrapper)
        text = text.to_s if !text.is_a?(String) && text.respond_to?(:to_s)
      rescue Exception => e
        text = { :error => e.message.split(/cutlist_packing_worker[.]rb:\d+:/).last } # Remove path in exception message
      end

      text
    end

    # -----

    class PackingData

      def initialize(

        number:,
        path:,
        instance_name:,
        name:,
        cutting_length:,
        cutting_width:,
        cutting_thickness:,
        edge_cutting_length:,
        edge_cutting_width:,
        bbox_length:,
        bbox_width:,
        bbox_thickness:,
        final_area:,
        material:,
        description:,
        url:,
        tags:,
        edge_ymin:,
        edge_ymax:,
        edge_xmin:,
        edge_xmax:,
        face_zmin:,
        face_zmax:,
        layer:,

        component_definition:,
        component_instance:


      )

        @number =  number
        @path = path
        @instance_name = instance_name
        @name = name
        @cutting_length = cutting_length
        @cutting_width = cutting_width
        @cutting_thickness = cutting_thickness
        @edge_cutting_length = edge_cutting_length
        @edge_cutting_width = edge_cutting_width
        @bbox_length = bbox_length
        @bbox_width = bbox_width
        @bbox_thickness = bbox_thickness
        @final_area = final_area
        @material = material
        @material_type = material.type
        @material_name = material.name
        @material_description = material.description
        @material_url = material.url
        @description = description
        @url = url
        @tags = tags
        @edge_ymin = edge_ymin
        @edge_ymax = edge_ymax
        @edge_xmin = edge_xmin
        @edge_xmax = edge_xmax
        @face_zmin = face_zmin
        @face_zmax = face_zmax
        @layer = layer

        @component_definition = component_definition
        @component_instance = component_instance

      end

      def get_binding
        binding
      end

    end

  end

  # -----

  class CutlistPackingWorker < AbstractCutlistPackingWorker

    include PartDrawingHelper
    include PixelConverterHelper
    include MaterialAttributesCachingHelper
    include EstimationHelper

    COLORIZATION_NONE = 0
    COLORIZATION_SCREEN = 1
    COLORIZATION_SCREEN_AND_PRINT = 2

    AVAILABLE_ROTATIONS = {
      "0" => [
        { start: 0, end: 0 },
      ],
      "180" => [
        { start: 0, end: 0 },
        { start: 180, end: 180 },
      ],
      "90" => [
        { start: 0, end: 0 },
        { start: 90, end: 90 },
        { start: 180, end: 180 },
        { start: 270, end: 270 },
      ]
    }

    def initialize(cutlist,

                   group_id:,
                   part_ids: nil,

                   std_bin_1d_sizes: '',
                   std_bin_2d_sizes: '',
                   scrap_bin_1d_sizes: '',
                   scrap_bin_2d_sizes: '',

                   problem_type: Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE,
                   optimization_mode: Packy::OPTIMIZATION_MODE_NOT_ANYTIME,
                   objective: Packy::OBJECTIVE_BIN_PACKING_WITH_LEFTOVERS,
                   spacing: '20mm',
                   trimming: '10mm',
                   time_limit: 20,
                   not_anytime_tree_search_queue_size: 16,
                   verbosity_level: 0,

                   items_formula: '',
                   hide_part_list: false,
                   part_drawing_type: PART_DRAWING_TYPE_NONE,
                   colorization: COLORIZATION_SCREEN,
                   origin_corner: ORIGIN_CORNER_TOP_LEFT,
                   hide_edges_preview: true,

                   rectangleguillotine_cut_type: Packy::RECTANGLEGUILLOTINE_CUT_TYPE_NON_EXACT,
                   rectangleguillotine_number_of_stages: 3,
                   rectangleguillotine_first_stage_orientation: 'horizontal',
                   rectangleguillotine_keep_length: '100mm',
                   rectangleguillotine_keep_width: '100mm',

                   irregular_allowed_rotations: '0',
                   irregular_allow_mirroring: false

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids

      @std_bin_1d_sizes = DimensionUtils.d_to_ifloats(std_bin_1d_sizes)
      @std_bin_2d_sizes = DimensionUtils.dxd_to_ifloats(std_bin_2d_sizes)
      @scrap_bin_1d_sizes = DimensionUtils.dxq_to_ifloats(scrap_bin_1d_sizes)
      @scrap_bin_2d_sizes = DimensionUtils.dxdxq_to_ifloats(scrap_bin_2d_sizes)

      @problem_type = problem_type
      @optimization_mode = optimization_mode
      @objective = objective
      @spacing = DimensionUtils.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.str_to_ifloat(trimming).to_l.to_f
      @time_limit = [ 1 , time_limit.to_i ].max
      @not_anytime_tree_search_queue_size = [ 1 , not_anytime_tree_search_queue_size.to_i ].max
      @verbosity_level = verbosity_level.to_i

      @items_formula = items_formula.empty? ? '@number' : items_formula
      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type.to_i
      @colorization = colorization
      @origin_corner = problem_type == Packy::PROBLEM_TYPE_IRREGULAR ? ORIGIN_CORNER_BOTTOM_LEFT : origin_corner.to_i                                         # Force origin corner to BOTTOM LEFT if IRREGULAR
      @hide_edges_preview = problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL || problem_type == Packy::PROBLEM_TYPE_IRREGULAR ? true : hide_edges_preview   # Force hide edges preview to true if ONEDIMENSIONAL or IRREGULAR

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
      @rectangleguillotine_number_of_stages = [ [ 2, rectangleguillotine_number_of_stages.to_i ].max, 3 ].min
      @rectangleguillotine_first_stage_orientation = rectangleguillotine_first_stage_orientation
      @rectangleguillotine_keep_length = DimensionUtils.str_to_ifloat(rectangleguillotine_keep_length).to_l.to_f
      @rectangleguillotine_keep_width = DimensionUtils.str_to_ifloat(rectangleguillotine_keep_width).to_l.to_f

      @irregular_allowed_rotations = irregular_allowed_rotations.to_s
      @irregular_allow_mirroring = irregular_allow_mirroring

      # Internals

      @_running = false
      @bin_type_defs = []
      @item_type_defs = []

    end

    # -----

    def run(action = :start)
      case action
      when :start

        return _create_packing(errors: [ 'default.error' ]) if @_running
        return _create_packing(errors: [ 'default.error' ]) unless @cutlist

        model = Sketchup.active_model
        return _create_packing(errors: [ 'default.error' ]) unless model

        group = @group = @cutlist.get_group(@group_id)
        return _create_packing(errors: [ 'default.error' ]) unless group

        parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids)
        return _create_packing(errors: [ 'tab.cutlist.packing.error.no_part' ]) if parts.empty?

        bin_types = []

        # Create bins from scrap bins
        scrap_bin_sizes = group.material_is_1d ? @scrap_bin_1d_sizes : @scrap_bin_2d_sizes
        scrap_bin_sizes.split(DimensionUtils::LIST_SEPARATOR).each do |scrap_bin_size|

          if group.material_is_1d
            dq = scrap_bin_size.split(DimensionUtils::DXD_SEPARATOR)
            length = dq[0].strip.to_l.to_f
            width = group.def.std_width.to_f
            count = [ 1, (dq[1].nil? || dq[1].strip.to_i == 0) ? 1 : dq[1].strip.to_i ].max
          else
            ddq = scrap_bin_size.split(DimensionUtils::DXD_SEPARATOR)
            length = ddq[0].strip.to_l.to_f
            width = ddq[1].strip.to_l.to_f
            count = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
          end

          next if length == 0 || width == 0 || count == 0

          cost, std_price = _compute_bin_type_cost(group, length, width)

          bin_type = {
            copies: count,
            width: _to_packy_length(length),
            height: _to_packy_length(width),
            cost: cost
          }
          if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
            bin_type[:left_trim] = bin_type[:right_trim] = bin_type[:bottom_trim] = bin_type[:top_trim] = _to_packy_length(@trimming)
          elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
            bin_type[:type] = 'rectangle'
          end
          bin_types << bin_type
          @bin_type_defs << BinTypeDef.new(
            Digest::MD5.hexdigest("#{length}_#{width}_1"),
            length,
            width,
            count,
            cost,
            std_price,
            1 # 1 = Bin "user defined"
          )

        end

        # Create bins from std bins
        std_bin_sizes = group.material_is_1d ? @std_bin_1d_sizes : @std_bin_2d_sizes
        std_bin_sizes.split(DimensionUtils::LIST_SEPARATOR).each do |std_bin_size|

          if group.material_is_1d
            length = std_bin_size.strip.to_l.to_f
            width = group.def.std_width.to_f
          else
            dd = std_bin_size.split(DimensionUtils::DXD_SEPARATOR)
            length = dd[0].strip.to_l.to_f
            width = dd[1].strip.to_l.to_f
          end

          next if length == 0 || width == 0

          cost, std_price = _compute_bin_type_cost(group, length, width)

          bin_type = {
            copies: -1,
            width: _to_packy_length(length),
            height: _to_packy_length(width),
            cost: cost
          }
          if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
            bin_type[:left_trim] = bin_type[:right_trim] = bin_type[:bottom_trim] = bin_type[:top_trim] = _to_packy_length(@trimming)
          elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
            bin_type[:type] = 'rectangle'
          end
          bin_types << bin_type
          @bin_type_defs << BinTypeDef.new(
            Digest::MD5.hexdigest("#{length}_#{width}_0"),
            length,
            width,
            -1,
            cost,
            std_price,
            0 # 0 = Bin "Standard"
          )

        end

        # Iterate on bin types to avoid nul cost
        min_cost_bin_type = bin_types.select { |bin_type| bin_type[:cost] > 0 }.min { |bin_type_a,bin_type_b| bin_type_a[:cost] <=> bin_type_b[:cost] }
        default_cost = min_cost_bin_type.nil? || min_cost_bin_type[:cost] == 0 ? -1 : min_cost_bin_type[:cost] / 10
        bin_types.each do |bin_type|
          bin_type[:cost] = default_cost if bin_type[:cost] == 0
        end

        return _create_packing(errors: [ "tab.cutlist.packing.error.no_bin_#{group.material_is_1d ? '1d' : '2d'}" ]) if bin_types.empty?

        item_types = []

        # Add items from parts
        fn_add_items = lambda { |part|

          count = part.count
          projection_def = _compute_part_projection_def(@part_drawing_type, part, compute_shell: true)

          if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR

            length = part.def.size.length
            width = part.def.size.width

            item_types << {
              copies: part.count,
              shapes: projection_def.shell_def.shape_defs.map { |shape_def| {
                type: 'polygon',
                vertices: shape_def.outer_poly_def.points.map { |point| { x: _to_packy_length(point.x), y: _to_packy_length(point.y) } },
                holes: shape_def.holes_poly_defs.map { |poly_def| {
                  type: 'polygon',
                  vertices: poly_def.points.map { |point| { x: _to_packy_length(point.x), y: _to_packy_length(point.y) } }
                }},
              }},
              allowed_rotations: AVAILABLE_ROTATIONS.fetch(@irregular_allowed_rotations, []),
              allow_mirroring: @irregular_allow_mirroring
            }

          else

            length = part.def.cutting_size.length
            width = part.def.cutting_size.width

            item_types << {
              copies: count,
              width: _to_packy_length(length),
              height: _to_packy_length(width),
              oriented: (group.material_grained && !part.ignore_grain_direction) ? true : false
            }

          end

          @item_type_defs << ItemTypeDef.new(
            length,
            width,
            count,
            part,
            projection_def,
            @colorization > COLORIZATION_NONE ? ColorUtils.color_lighten(ColorUtils.color_create("##{Digest::SHA1.hexdigest(part.number.to_s)[0..5]}"), 0.8) : nil
          )

        }
        parts.each { |part|
          if part.instance_of?(FolderPart)
            part.children.each { |child_part| fn_add_items.call(child_part) }
          else
            fn_add_items.call(part)
          end
        }

        return _create_packing(errors: [ 'tab.cutlist.packing.error.no_part' ]) if item_types.empty?

        instance_parameters = {}
        if @problem_type == Packy::PROBLEM_TYPE_RECTANGLE || @problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL
          instance_parameters = {
            fake_trimming: _to_packy_length(@trimming),
            fake_spacing: _to_packy_length(@spacing)
          }
        elsif @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
          instance_parameters = {
            cut_type: @rectangleguillotine_cut_type,
            cut_thickness: _to_packy_length(@spacing),
            number_of_stages: @rectangleguillotine_number_of_stages,
            first_stage_orientation: @rectangleguillotine_first_stage_orientation,
            keep_width: _to_packy_length(@rectangleguillotine_keep_length),
            keep_height: _to_packy_length(@rectangleguillotine_keep_width)
          }
        elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
          instance_parameters = {
            item_bin_minimum_spacing: _to_packy_length(@trimming),
            item_item_minimum_spacing: _to_packy_length(@spacing)
          }
        end

        input = {
          problem_type: @problem_type,
          parameters: {
            length_truncate_factor: DimensionUtils.model_unit_is_metric ? 254.0 : 100.0,
            optimization_mode: @optimization_mode,
            time_limit: @time_limit,
            not_anytime_tree_search_queue_size: @not_anytime_tree_search_queue_size,
            verbosity_level: @verbosity_level
          },
          instance: {
            objective: @objective,
            parameters: instance_parameters,
            bin_types: bin_types,
            item_types: item_types,
          }
        }

        if @verbosity_level > 0
          SKETCHUP_CONSOLE.clear
          puts '-- input --'
          puts input.to_json
          puts '-- input --'
        end

        output = Packy.optimize_start(input)

        @_running = true

        return _create_packing(output: output)

      when :advance

        return _create_packing(errors: [ 'default.error' ]) unless @_running

        output = Packy.optimize_advance

        return _create_packing(output: output)

      when :cancel

        return _create_packing(errors: [ 'default.error' ]) unless @_running

        Packy.optimize_cancel

        return _create_packing(output: { 'cancelled' => true })
      end

      _create_packing(errors: [ 'default.error' ])
    end

    private

    def _create_packing(output: {}, errors: nil)

      running = output.fetch('running', false)

      return PackingDef.new(errors: errors).create_packing if errors.is_a?(Array)
      return PackingDef.new(cancelled: true).create_packing if output['cancelled']
      return PackingDef.new(running: true).create_packing if running && output['solution'].nil?

      if @verbosity_level > 1
        puts ' '
        puts '-- output --'
        puts output.to_json
        puts '-- output --'
      end

      return PackingDef.new(errors: [ [ 'core.error.extern', { 'error' => output['error'] } ] ]).create_packing if output.has_key?('error')

      raw_solution = output['solution']

      return PackingDef.new(errors: [ 'tab.cutlist.packing.error.no_solution' ]).create_packing if raw_solution.nil? || raw_solution['bins'].nil? || raw_solution['bins'].empty?

      # Create PackingDef from solution

      instance_info_by_item_type_def = {}
      @item_type_defs.each do |item_type_def|
        instance_infos = []
        item_type_def.part.def.thickness_layer_count.times do
          instance_infos += item_type_def.part.def.instance_infos.values
        end
        instance_info_by_item_type_def[item_type_def] = instance_infos
      end

      packing_def = PackingDef.new(
        group: @group,
        running: running,
        solution_def: PackingSolutionDef.new(
          options_def: PackingOptionsDef.new(
            problem_type: @problem_type,
            spacing: @spacing,
            trimming: @trimming,
            items_formula: @items_formula,
            hide_part_list: @hide_part_list,
            part_drawing_type: @part_drawing_type,
            colorization: @colorization,
            origin_corner: @origin_corner,
            rectangleguillotine_cut_type: @rectangleguillotine_cut_type,
            rectangleguillotine_first_stage_orientation: @rectangleguillotine_first_stage_orientation,
            rectangleguillotine_number_of_stages: @rectangleguillotine_number_of_stages,
            rectangleguillotine_keep_length: @rectangleguillotine_keep_length,
            rectangleguillotine_keep_width: @rectangleguillotine_keep_width,
            irregular_allowed_rotations: @irregular_allowed_rotations,
            irregular_allow_mirroring: @irregular_allow_mirroring
          ),
          summary_def: PackingSummaryDef.new(
            time: raw_solution['time'],
            number_of_bins: raw_solution['number_of_bins'],
            number_of_items: raw_solution['number_of_items'],
            efficiency: raw_solution['full_efficiency'],
            bin_type_stats_defs: raw_solution['bin_types_stats'].is_a?(Array) ? raw_solution['bin_types_stats'].map { |raw_bin_type_stats|
              bin_type_def = @bin_type_defs[raw_bin_type_stats['bin_type_id']]
              used_copies = raw_bin_type_stats.fetch('used_copies', 0)
              unused_copies = raw_bin_type_stats.fetch('unused_copies', 0)
              defs = []
              defs << PackingSummaryBinTypeStatsDef.new(bin_type_def: bin_type_def, count: used_copies, used: true, number_of_items: raw_bin_type_stats.fetch('item_copies', 0)) if used_copies > 0
              defs << PackingSummaryBinTypeStatsDef.new(bin_type_def: bin_type_def, count: unused_copies, used: false) if unused_copies > 0 || unused_copies == -1
              defs
            }.flatten(1).sort_by!{ |bin_type_stats| [ bin_type_stats.used ? 1 : 0, -bin_type_stats.bin_type_def.type, bin_type_stats.bin_type_def.length ]} : []
          ),
          unplaced_part_info_defs: raw_solution['item_types_stats'].is_a?(Array) ? raw_solution['item_types_stats'].map { |raw_item_type_stats|
            item_type_def = @item_type_defs[raw_item_type_stats['item_type_id']]
            unused_copies = raw_item_type_stats.fetch('unused_copies', 0)
            next if unused_copies == 0
            PackingPartInfoDef.new(part: item_type_def.part, count: unused_copies)
          }.compact.sort_by! { |part_info_def| part_info_def._sorter } : [],
          bin_defs: raw_solution['bins'].map { |raw_bin|
            bin_type_def = @bin_type_defs[raw_bin['bin_type_id']]
            PackingBinDef.new(
              bin_type_def: bin_type_def,
              count: raw_bin['copies'],
              efficiency: raw_bin['efficiency'],
              item_defs: raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
                item_type_def = @item_type_defs[raw_item['item_type_id']]
                PackingItemDef.new(
                  item_type_def: item_type_def,
                  instance_info: instance_info_by_item_type_def[item_type_def].is_a?(Array) ? instance_info_by_item_type_def[item_type_def].shift : nil,
                  x: _from_packy_length(raw_item.fetch('x', 0)),
                  y: _from_packy_length(raw_item.fetch('y', 0)),
                  angle: raw_item.fetch('angle', 0),
                  mirror: raw_item.fetch('mirror', false)
                )
              } : [],
              leftover_defs: raw_bin['leftovers'].is_a?(Array) ? raw_bin['leftovers'].map { |raw_leftover|
                PackingLeftoverDef.new(
                  x: _from_packy_length(raw_leftover.fetch('x', 0)),
                  y: _from_packy_length(raw_leftover.fetch('y', 0)),
                  length: _from_packy_length(raw_leftover.fetch('width', 0)),
                  width: _from_packy_length(raw_leftover.fetch('height', 0)),
                  kept: raw_leftover.fetch('kept', false),
                )
              } : [],
              cut_defs: raw_bin['cuts'].is_a?(Array) ? raw_bin['cuts'].map { |raw_cut|
                PackingCutDef.new(
                  depth: raw_cut['depth'],
                  x: _from_packy_length(raw_cut.fetch('x', 0)),
                  y: _from_packy_length(raw_cut.fetch('y', 0)),
                  length: (raw_cut['length'] ? _from_packy_length(raw_cut['length']) : bin_type_def.width),
                  orientation: raw_cut.fetch('orientation', 'vertical')
                )
              }.sort_by { |cut_def| cut_def.depth } : [],
              part_info_defs: raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
                @item_type_defs[raw_item['item_type_id']]
              }.group_by { |i| i }.map { |item_type_def, v|
                PackingPartInfoDef.new(
                  part: item_type_def.part,
                  count: v.length
                )
              }.sort_by { |part_info_def| part_info_def._sorter } : [],
              number_of_items: raw_bin.fetch('number_of_items', 0),
              number_of_leftovers: raw_bin.fetch('number_of_leftovers', 0),
              number_of_leftovers_to_keep: raw_bin.fetch('number_of_leftovers_to_keep', 0),
              number_of_cuts: raw_bin.fetch('number_of_cuts', 0),
              cut_length: _from_packy_length(raw_bin.fetch('cut_length', 0)),
              x_max: _from_packy_length(raw_bin.fetch('x_max', 0)),
              y_max: _from_packy_length(raw_bin.fetch('y_max', 0))
            )
          }.sort_by { |bin_def| [ -bin_def.bin_type_def.type, bin_def.bin_type_def.length, -bin_def.efficiency, -bin_def.count ] }
        )
      )

      # Computed values

      packing_def.solution_def.bin_defs.each do |bin_def|

        bin_def.svg = _render_bin_def_svg(bin_def, false) unless running
        bin_def.light_svg = _render_bin_def_svg(bin_def, true)

        packing_def.solution_def.summary_def.number_of_leftovers += bin_def.number_of_leftovers
        packing_def.solution_def.summary_def.number_of_leftovers_to_keep += bin_def.number_of_leftovers_to_keep
        packing_def.solution_def.summary_def.number_of_cuts += bin_def.number_of_cuts
        packing_def.solution_def.summary_def.cut_length += bin_def.cut_length

      end

      # Sum bins stats
      packing_def.solution_def.summary_def.bin_type_stats_defs.each do |bin_type_stats_def|
        next unless bin_type_stats_def.used
        packing_def.solution_def.summary_def.total_used_count += bin_type_stats_def.count
        packing_def.solution_def.summary_def.total_used_area += bin_type_stats_def.total_area
        packing_def.solution_def.summary_def.total_used_length += bin_type_stats_def.total_length
        packing_def.solution_def.summary_def.total_used_cost += bin_type_stats_def.total_cost
        packing_def.solution_def.summary_def.total_used_item_count += bin_type_stats_def.number_of_items
      end

      # Sum item stats
      packing_def.solution_def.unplaced_part_info_defs.each do |part_info_def|
        packing_def.solution_def.summary_def.total_unused_item_count += part_info_def.count
      end

      packing_def.create_packing
    end

    def _to_packy_length(l)
      l.to_f
    end

    def _from_packy_length(l)
      l.to_l
    end

    def _compute_bin_type_cost(group, inch_length = 0, inch_width = 0, inch_thickness = 0)
      std_price = nil
      cost = -1
      if (material_attributes = _get_material_attributes(group.material_name)).has_std_prices?

        inch_thickness = group.def.std_thickness if inch_thickness == 0
        inch_width = group.def.std_width if inch_width == 0

        dim = material_attributes.compute_std_dim(inch_length, inch_width, inch_thickness)
        unless dim.nil?
          std_price = _get_std_price(dim, material_attributes)
          price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], inch_thickness, inch_width, inch_length)
          cost = (inch_length * inch_width * inch_thickness * price_per_inch3).round(2)
        end

      end
      [ cost, std_price ]
    end

    def _render_bin_def_svg(bin_def, light)

      uuid = SecureRandom.uuid

      colorized = @colorization > COLORIZATION_NONE && !light
      colorized_print = @colorization == COLORIZATION_SCREEN_AND_PRINT && !light

      px_bin_dimension_font_size = light ? 0 : 16
      px_node_dimension_font_size_max = 12
      px_node_dimension_font_size_min = 8
      px_node_number_font_size_max = 24
      px_node_number_font_size_min = 8

      px_bin_dimension_offset = light ? 0 : 10
      px_node_dimension_offset = 4
      px_node_edge_offset = 1

      px_bin_outline_width = 1
      px_cut_outline_width = 2
      px_edge_width = 2

      px_max_bin_length = _to_px(bin_def.bin_type_def.length) # TODO

      px_bin_length = _to_px(bin_def.bin_type_def.length)
      px_bin_width = _to_px(bin_def.bin_type_def.width)
      px_trimming = _to_px(@trimming)
      px_spacing = _to_px(@spacing)

      is_1d = @problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL
      is_2d = !is_1d
      is_irregular = @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      is_cut_bg = px_spacing >= 3 && !light

      vb_offset_x = (px_max_bin_length - px_bin_length) / 2
      vb_x = (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size + vb_offset_x) * -1
      vb_y = (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size) * -1
      vb_width = px_bin_length + (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size + vb_offset_x) * 2
      vb_height = px_bin_width + (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size) * 2

      svg = "<svg viewbox='#{vb_x} #{vb_y} #{vb_width} #{vb_height}' style='max-height: #{vb_height}px' class='packing problem-type-#{@problem_type}#{' no-print-color' unless colorized_print}'>"
        unless light
          svg += "<defs>"
            svg += "<pattern id='pattern_bin_bg_#{uuid}' width='10' height='10' patternUnits='userSpaceOnUse'>"
              svg += "<rect x='0' y='0' width='10' height='10' fill='white' />"
              svg += "<path d='M0,10L10,0' style='fill:none;stroke:#ddd;stroke-width:0.5px;'/>"
            svg += "</pattern>"
            if is_cut_bg
              svg += "<pattern id='pattern_cut_bg_#{uuid}' width='5' height='5' patternUnits='userSpaceOnUse'>"
                svg += "<rect x='0' y='0' width='5' height='5' fill='white'/>"
                svg += "<path d='M0,5L5,0' style='fill:none;stroke:#000;stroke-width:0.5px;'/>"
              svg += "</pattern>"
            end
          svg += "</defs>"
          svg += "<text class='bin-dimension' x='#{px_bin_length / 2}' y='#{-(px_bin_outline_width + px_bin_dimension_offset)}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic'>#{bin_def.bin_type_def.length.to_l}</text>"
          svg += "<text class='bin-dimension' x='#{-(px_bin_outline_width + px_bin_dimension_offset)}' y='#{px_bin_width / 2}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic' transform='rotate(-90 -#{px_bin_outline_width + px_bin_dimension_offset},#{px_bin_width / 2})'>#{bin_def.bin_type_def.width.to_l}</text>"
        end
        svg += "<g class='bin'>"
          svg += "<rect class='bin-outer' x='-1' y='-1' width='#{px_bin_length + 2}' height='#{px_bin_width + 2}' />"
          svg += "<rect class='bin-inner' x='0' y='0' width='#{px_bin_length}' height='#{px_bin_width}' fill='#{light ? '#fff' : "url(#pattern_bin_bg_#{uuid})"}'/>"
          unless light
            if is_1d
              svg += "<line class='bin-trimming' x1='#{px_trimming}' y1='0' x2='#{px_trimming}' y2='#{px_bin_width}'/>" if @trimming > 0
              svg += "<line class='bin-trimming' x1='#{px_bin_length - px_trimming}' y1='0' x2='#{px_bin_length - px_trimming}' y2='#{px_bin_width}'/>" if @trimming > 0
            elsif is_2d
              svg += "<rect class='bin-trimming' x='#{px_trimming}' y='#{px_trimming}' width='#{px_bin_length - px_trimming * 2}' height='#{px_bin_width - px_trimming * 2}'/>" if @trimming > 0
            end
          end
          if bin_def.x_max > 0 && bin_def.x_max < bin_def.bin_type_def.length - @trimming - 20.mm   # Arbitrary remove 20mm to avoid displaying line near border
            px_bin_max_x = _compute_x_with_origin_corner(@problem_type, @origin_corner, _to_px(bin_def.x_max), 0, px_bin_length)
            svg += "<g class='bin-max'#{" data-toggle='tooltip' data-html='true' title='#{_render_bin_max_tooltip(bin_def.x_max, "vertical-cut-#{@origin_corner == ORIGIN_CORNER_BOTTOM_LEFT || @origin_corner == ORIGIN_CORNER_TOP_LEFT ? 'right' : 'left'}")}'" unless light}>"
              svg += "<rect class='bin-max-outer' x='#{px_bin_max_x - px_cut_outline_width}' y='0' width='#{px_cut_outline_width * 2}' height='#{px_bin_width}'/>" unless light
              svg += "<line class='bin-max-inner' x1='#{px_bin_max_x}' y1='0' x2='#{px_bin_max_x}' y2='#{px_bin_width}'#{" style='stroke:red'" if light}>/>"
            svg += "</g>"
          end
          if bin_def.y_max > 0 && bin_def.y_max < bin_def.bin_type_def.width - @trimming - 20.mm   # Arbitrary remove 20mm to avoid displaying line near border
            px_bin_max_y = px_bin_width - _compute_y_with_origin_corner(@problem_type, @origin_corner, _to_px(bin_def.y_max), 0, px_bin_width)
            svg += "<g class='bin-max'#{" data-toggle='tooltip' data-html='true' title='#{_render_bin_max_tooltip(bin_def.y_max, "horizontal-cut-#{@origin_corner == ORIGIN_CORNER_BOTTOM_LEFT || @origin_corner == ORIGIN_CORNER_BOTTOM_RIGHT ? 'top' : 'bottom'}")}'" unless light}>"
              svg += "<rect class='bin-max-outer' x='0' y='#{px_bin_max_y - px_cut_outline_width}' width='#{px_bin_length}' height='#{px_cut_outline_width * 2}'/>" unless light
              svg += "<line class='bin-max-inner' x1='0' y1='#{px_bin_max_y}' x2='#{px_bin_length}' y2='#{px_bin_max_y}'#{" style='stroke:red'" if light}/>"
            svg += "</g>"
          end
        svg += '</g>'
        bin_def.item_defs.each do |item_def|

          item_type_def = item_def.item_type_def
          projection_def = item_type_def.projection_def
          part = item_type_def.part
          part_def = part.def

          px_item_length = _to_px(item_type_def.length)
          px_item_width = is_1d ? px_bin_width : _to_px(item_type_def.width)
          px_item_x = _to_px(item_def.x)
          px_item_y = _to_px(item_def.y)

          px_part_length = _to_px(part_def.size.length)
          px_part_width = _to_px(part_def.size.width)

          bounds = _compute_item_bounds_in_bin_space(px_item_length, px_item_width, item_def)

          px_item_rect_width = bounds.width.to_f
          px_item_rect_height = bounds.height.to_f
          px_item_rect_x = _compute_x_with_origin_corner(@problem_type, @origin_corner, px_item_x + bounds.min.x.to_f, px_item_rect_width, px_bin_length)
          px_item_rect_y = px_bin_width - _compute_y_with_origin_corner(@problem_type, @origin_corner, px_item_y + bounds.min.y.to_f, px_item_rect_height, px_bin_width)

          svg += "<g class='item' transform='translate(#{px_item_rect_x} #{px_item_rect_y})'#{" data-toggle='tooltip' data-html='true' title='#{_render_item_def_tooltip(item_def)}' data-part-id='#{part.id}'" unless light}>"
            svg += "<rect class='item-outer' x='0' y='#{-px_item_rect_height}' width='#{px_item_rect_width}' height='#{px_item_rect_height}'#{" style='fill:#{projection_def.nil? && colorized ? ColorUtils.color_to_hex(item_type_def.color) : '#eee'};stroke:#555'" if light || (projection_def.nil? && colorized)}/>" unless is_irregular

            unless projection_def.nil? || light && !is_irregular
              svg += "<g class='item-projection' transform='translate(#{px_item_rect_width / 2} #{-px_item_rect_height / 2})#{" rotate(#{-item_def.angle})" if item_def.angle != 0}#{' scale(-1 1)' if item_def.mirror} translate(#{-px_part_length / 2} #{px_part_width / 2})'>"
                svg += "<path stroke='#{colorized && !is_irregular ? ColorUtils.color_to_hex(ColorUtils.color_darken(item_type_def.color, 0.4)) : '#000'}' fill='#{colorized ? ColorUtils.color_to_hex(item_type_def.color) : '#eee'}' stroke-width='0.5' class='item-projection-shape' d='#{projection_def.layer_defs.map { |layer_def| "#{layer_def.poly_defs.map { |poly_def| "M #{(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points).map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}" }.join(' ')}' />"
              svg += '</g>'
            end

            unless light

              if !@hide_edges_preview && part_def.edge_count > 0

                svg += "<g class='item-projection' transform='#{" rotate(#{-item_def.angle})" if item_def.angle != 0}'>"
                  svg += "<rect x='#{px_node_edge_offset}' y='#{-px_edge_width - px_node_edge_offset}' width='#{px_item_length - 2 * px_node_edge_offset}' height='#{px_edge_width}' fill='#{ColorUtils.color_to_hex(part_def.edge_material_colors[:ymin])}'/>" unless part_def.edge_material_names[:ymin].nil?
                  svg += "<rect x='#{px_node_edge_offset}' y='#{-px_item_width + px_node_edge_offset}' width='#{px_item_length - 2 * px_node_edge_offset}' height='#{px_edge_width}' fill='#{ColorUtils.color_to_hex(part_def.edge_material_colors[:ymax])}'/>" unless part_def.edge_material_names[:ymax].nil?
                  svg += "<rect x='#{px_node_edge_offset}' y='#{-px_item_width + px_node_edge_offset}' width='#{px_edge_width}' height='#{px_item_width - 2 * px_node_edge_offset}' fill='#{ColorUtils.color_to_hex(part_def.edge_material_colors[:xmin])}'/>" unless part_def.edge_material_names[:xmin].nil?
                  svg += "<rect x='#{px_item_length - px_edge_width - px_node_edge_offset}' y='#{-px_item_width + px_node_edge_offset}' width='#{px_edge_width}' height='#{px_item_width - 2 * px_node_edge_offset}' fill='#{ColorUtils.color_to_hex(part_def.edge_material_colors[:xmax])}'/>" unless part_def.edge_material_names[:xmax].nil?
                svg += '</g>'

              end

              item_text = _evaluate_item_text(@items_formula, part, item_def.instance_info)
              item_text = "<tspan data-toggle='tooltip' title='#{CGI::escape_html(item_text[:error])}' fill='red'>!!</tspan>" if item_text.is_a?(Hash)

              number_font_size = [ [ px_node_number_font_size_max, px_item_rect_height / 2, px_item_rect_width / (item_text.length * 0.6) ].min, px_node_number_font_size_min ].max

              svg += "<text class='item-number' x='0' y='0' font-size='#{number_font_size}' text-anchor='middle' dominant-baseline='central' transform='translate(#{px_item_rect_width / 2} #{-px_item_rect_height / 2}) rotate(#{-(item_def.angle % 180)})'>#{item_text}</text>"

              unless is_irregular

                dim_x = item_def.angle == 0 ? part_def.cutting_length : part_def.cutting_width
                dim_y = item_def.angle == 0 ? part_def.cutting_width : part_def.cutting_length
                is_cutting_dim_x = dim_x != (item_def.angle == 0 ? part_def.size.length : part_def.size.width)
                is_cutting_dim_y = dim_y != (item_def.angle == 0 ? part_def.size.width : part_def.size.length)

                dim_x_text = dim_x.to_s.gsub(/~ /, '')
                dim_y_text = dim_y.to_s.gsub(/~ /, '')

                if is_2d

                  px_number_w, px_number_h = _compute_text_size(text: item_text, size: number_font_size)
                  px_number_bounds = Geom::BoundingBox.new.add(
                    [
                      Geom::Point3d.new(-px_number_w / 2, -px_number_h / 2),
                      Geom::Point3d.new(px_number_w / 2, px_number_h / 2)
                    ].map! { |point| point.transform!(Geom::Transformation.translation(Geom::Vector3d.new(px_item_rect_width / 2, px_item_rect_height / 2)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, (item_def.angle % 180).degrees)) }
                  )
                  # svg += "<rect x='#{px_number_bounds.min.x.to_f}' y='#{(-px_item_rect_height + px_number_bounds.min.y).to_f}' width='#{px_number_bounds.width.to_f}' height='#{px_number_bounds.height.to_f}' fill='none' stroke='red'></rect>"

                  dim_x_font_size = [ [ px_node_dimension_font_size_max, px_item_rect_height - px_node_dimension_offset * 2, (px_item_rect_width - px_node_dimension_offset * 2) / (dim_x_text.length * 0.6) ].min, px_node_dimension_font_size_min ].max
                  dim_y_font_size = [ [ px_node_dimension_font_size_max, px_item_rect_width - px_node_dimension_offset * 2, (px_item_rect_height - px_node_dimension_offset * 2) / (dim_y_text.length * 0.6) ].min, px_node_dimension_font_size_min ].max

                  px_dim_x_w, px_dim_x_h = _compute_text_size(text: dim_x_text, size: dim_x_font_size)
                  px_dim_x_bounds = Geom::BoundingBox.new.add(
                    [
                      Geom::Point3d.new,
                      Geom::Point3d.new(px_dim_x_w, px_dim_x_h)
                    ].map! { |point| point.transform!(Geom::Transformation.translation(Geom::Vector3d.new(px_item_rect_width - px_node_dimension_offset - px_dim_x_w, px_node_dimension_offset))) }
                  )
                  # svg += "<rect x='#{px_dim_x_bounds.min.x.to_f}' y='#{(-px_item_rect_height + px_dim_x_bounds.min.y).to_f}' width='#{px_dim_x_bounds.width.to_f}' height='#{px_dim_x_bounds.height.to_f}' fill='none' stroke='cyan'></rect>"

                  px_dim_y_w, px_dim_y_h = _compute_text_size(text: dim_y_text, size: dim_y_font_size)
                  px_dim_y_bounds = Geom::BoundingBox.new.add(
                    [
                      Geom::Point3d.new,
                      Geom::Point3d.new(px_dim_y_w, px_dim_y_h)
                    ].map! { |point| point.transform!(Geom::Transformation.translation(Geom::Vector3d.new(px_node_dimension_offset, px_item_rect_height - px_node_dimension_offset)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, -90.degrees)) }
                  )
                  # svg += "<rect x='#{px_dim_y_bounds.min.x.to_f}' y='#{(-px_item_rect_height + px_dim_y_bounds.min.y).to_f}' width='#{px_dim_y_bounds.width.to_f}' height='#{px_dim_y_bounds.height.to_f}' fill='none' stroke='yellow'></rect>"

                  hide_dim_x = px_number_bounds.intersect(px_dim_x_bounds).valid? || px_dim_x_bounds.width > px_item_rect_width - px_node_dimension_offset || px_dim_x_bounds.height > px_item_rect_height - px_node_dimension_offset
                  hide_dim_y = px_number_bounds.intersect(px_dim_y_bounds).valid? || px_dim_y_bounds.width > px_item_rect_width - px_node_dimension_offset || px_dim_y_bounds.height > px_item_rect_height - px_node_dimension_offset

                  svg += "<text class='item-dimension#{' item-dimension-cutting' if is_cutting_dim_x}' x='#{px_item_rect_width - px_node_dimension_offset}' y='#{-(px_item_rect_height - px_node_dimension_offset)}' font-size='#{dim_x_font_size}' text-anchor='end' dominant-baseline='hanging'>#{dim_x_text}</text>" unless hide_dim_x
                  svg += "<text class='item-dimension#{' item-dimension-cutting' if is_cutting_dim_y}' x='#{px_node_dimension_offset}' y='#{-px_node_dimension_offset}' font-size='#{dim_y_font_size}' text-anchor='start' dominant-baseline='hanging' transform='rotate(-90 #{px_node_dimension_offset} -#{px_node_dimension_offset})'>#{dim_y_text}</text>" unless hide_dim_y
                elsif is_1d
                  svg += "<text class='item-dimension#{' item-dimension-cutting' if is_cutting_dim_x}' x='#{px_item_rect_width / 2}' y='#{px_bin_dimension_offset}' font-size='#{px_node_dimension_font_size_max}' text-anchor='middle' dominant-baseline='hanging'>#{dim_x_text}</text>"
                end

              end
            end

          svg += "</g>"

        end
        unless light
          bin_def.leftover_defs.each do |leftover_def|

            px_leftover_rect_width = _to_px(leftover_def.length)
            px_leftover_rect_height = is_1d ? px_bin_width : _to_px(leftover_def.width)
            px_leftover_rect_x = _compute_x_with_origin_corner(@problem_type, @origin_corner, _to_px(leftover_def.x), px_leftover_rect_width, px_bin_length)
            px_leftover_rect_y = px_bin_width - _compute_y_with_origin_corner(@problem_type, @origin_corner, _to_px(leftover_def.y), px_leftover_rect_height, px_bin_width)

            dim_x_text = leftover_def.length.to_s.gsub(/~ /, '')
            dim_y_text = leftover_def.width.to_s.gsub(/~ /, '')

            svg += "<g class='leftover' transform='translate(#{px_leftover_rect_x} #{px_leftover_rect_y})'#{" data-toggle='tooltip' data-html='true' title='#{_render_leftover_def_tooltip(leftover_def)}'" if leftover_def.kept}>"
              svg += "<rect class='leftover-inner' x='0' y='#{-px_leftover_rect_height}' width='#{px_leftover_rect_width}' height='#{px_leftover_rect_height}'/>" if leftover_def.kept
              if is_2d

                dim_x_font_size = [ [ px_node_dimension_font_size_max, px_leftover_rect_height - px_node_dimension_offset * 2, (px_leftover_rect_width - px_node_dimension_offset * 2) / (dim_x_text.length * 0.6) ].min, px_node_dimension_font_size_min ].max
                dim_y_font_size = [ [ px_node_dimension_font_size_max, px_leftover_rect_width - px_node_dimension_offset * 2, (px_leftover_rect_height - px_node_dimension_offset * 2) / (dim_y_text.length * 0.6) ].min, px_node_dimension_font_size_min ].max

                  px_dim_x_w, px_dim_x_h = _compute_text_size(text: dim_x_text, size: dim_x_font_size)
                  px_dim_x_bounds = Geom::BoundingBox.new.add(
                    [
                      Geom::Point3d.new,
                      Geom::Point3d.new(px_dim_x_w, px_dim_x_h)
                    ].map! { |point| point.transform!(Geom::Transformation.translation(Geom::Vector3d.new(px_leftover_rect_width - px_node_dimension_offset - px_dim_x_w, px_node_dimension_offset))) }
                  )
                  # svg += "<rect x='#{px_dim_x_bounds.min.x.to_f}' y='#{(-px_leftover_rect_height + px_dim_x_bounds.min.y).to_f}' width='#{px_dim_x_bounds.width.to_f}' height='#{px_dim_x_bounds.height.to_f}' fill='none' stroke='cyan'></rect>"

                  px_dim_y_w, px_dim_y_h = _compute_text_size(text: dim_y_text, size: dim_y_font_size)
                  px_dim_y_bounds = Geom::BoundingBox.new.add(
                    [
                      Geom::Point3d.new,
                      Geom::Point3d.new(px_dim_y_w, px_dim_y_h)
                    ].map! { |point| point.transform!(Geom::Transformation.translation(Geom::Vector3d.new(px_node_dimension_offset, px_leftover_rect_height - px_node_dimension_offset)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, -90.degrees)) }
                  )
                  # svg += "<rect x='#{px_dim_y_bounds.min.x.to_f}' y='#{(-px_leftover_rect_height + px_dim_y_bounds.min.y).to_f}' width='#{px_dim_y_bounds.width.to_f}' height='#{px_dim_y_bounds.height.to_f}' fill='none' stroke='yellow'></rect>"

                hide_dim_x = px_dim_x_bounds.width > px_leftover_rect_width - px_node_dimension_offset || px_dim_x_bounds.height > px_leftover_rect_height - px_node_dimension_offset
                hide_dim_y = px_dim_x_bounds.intersect(px_dim_y_bounds).valid? || px_dim_y_bounds.width > px_leftover_rect_width - px_node_dimension_offset || px_dim_y_bounds.height > px_leftover_rect_height - px_node_dimension_offset

                svg += "<text class='leftover-dimension' x='#{px_leftover_rect_width - px_node_dimension_offset}' y='#{-(px_leftover_rect_height - px_node_dimension_offset)}' font-size='#{dim_x_font_size}' text-anchor='end' dominant-baseline='hanging'>#{dim_x_text}</text>" unless hide_dim_x
                svg += "<text class='leftover-dimension' x='#{px_node_dimension_offset}' y='#{-px_node_dimension_offset}' font-size='#{dim_y_font_size}' text-anchor='start' dominant-baseline='hanging' transform='rotate(-90 #{px_node_dimension_offset} -#{px_node_dimension_offset})'>#{dim_y_text}</text>" unless hide_dim_y
              elsif is_1d
                svg += "<text class='leftover-dimension' x='#{px_leftover_rect_width / 2}' y='#{px_bin_dimension_offset}' font-size='#{px_node_dimension_font_size_max}' text-anchor='middle' dominant-baseline='hanging'>#{leftover_def.length.to_s.gsub(/~ /, '')}</text>"
              end
            svg += '</g>'

          end
          bin_def.cut_defs.each do |cut_def|

            px_cut_x = _to_px(cut_def.x)
            px_cut_y = px_bin_width - _to_px(cut_def.y)
            px_cut_length = _to_px(cut_def.length)
            px_cut_width = [ 1, px_spacing ].max

            if cut_def.orientation == 'horizontal'
              px_cut_rect_width = px_cut_length
              px_cut_rect_height = px_cut_width
            else
              px_cut_rect_width = px_cut_width
              px_cut_rect_height = px_cut_length
            end
            px_cut_rect_x = _compute_x_with_origin_corner(@problem_type, @origin_corner, px_cut_x, px_cut_rect_width, px_bin_length)
            px_cut_rect_y = _compute_y_with_origin_corner(@problem_type, @origin_corner, px_cut_y - px_cut_rect_height, px_cut_rect_height, px_bin_width)

            case cut_def.depth
            when 0
              clazz = ' cut-trimming'
            when 1
              clazz = ' cut-primary'
            else
              clazz = ''
            end
            clazz += ' cut-lg' if is_cut_bg

            svg += "<g class='cut#{clazz}' data-toggle='tooltip' data-html='true' title='#{_render_cut_def_tooltip(cut_def)}'>"
              svg += "<rect class='cut-outer' x='#{px_cut_rect_x - px_cut_outline_width}' y='#{px_cut_rect_y - px_cut_outline_width}' width='#{px_cut_rect_width + px_cut_outline_width * 2}' height='#{px_cut_rect_height + px_cut_outline_width * 2}' />"
              svg += "<rect class='cut-inner' x='#{px_cut_rect_x}' y='#{px_cut_rect_y}' width='#{px_cut_rect_width}' height='#{px_cut_rect_height}'#{" fill='url(#pattern_cut_bg_#{uuid})'" if is_cut_bg}/>"
            svg += "</g>"

          end
        end
      svg += '</svg>'

      svg
    end

    def _render_item_def_tooltip(item_def)
      part = item_def.item_type_def.part
      tt = "<div class=\"tt-header\"><span class=\"tt-number\">#{part.number}</span><span class=\"tt-name\">#{CGI::escape_html(part.name)}</span></div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-size-length-width\"></i> #{CGI::escape_html(part.cutting_length)}&nbsp;x&nbsp;#{CGI::escape_html(part.cutting_width)}</div>"
      if part.edge_count > 0
        tt += "<div class=\"tt-section\">"
          tt += "<div><i class=\"ladb-opencutlist-icon-edge-0010\"></i>&nbsp;#{CGI::escape_html(part.edge_material_names[:ymin])}&nbsp;<small>#{CGI::escape_html(part.edge_std_dimensions[:ymin])}</small></div>" if part.edge_material_names[:ymin]
          tt += "<div><i class=\"ladb-opencutlist-icon-edge-1000\"></i>&nbsp;#{CGI::escape_html(part.edge_material_names[:ymax])}&nbsp;<small>#{CGI::escape_html(part.edge_std_dimensions[:ymax])}</small></div>" if part.edge_material_names[:ymax]
          tt += "<div><i class=\"ladb-opencutlist-icon-edge-0001\"></i>&nbsp;#{CGI::escape_html(part.edge_material_names[:xmin])}&nbsp;<small>#{CGI::escape_html(part.edge_std_dimensions[:xmin])}</small></div>" if part.edge_material_names[:xmin]
          tt += "<div><i class=\"ladb-opencutlist-icon-edge-0100\"></i>&nbsp;#{CGI::escape_html(part.edge_material_names[:xmax])}&nbsp;<small>#{CGI::escape_html(part.edge_std_dimensions[:xmax])}</small></div>" if part.edge_material_names[:xmax]
        tt += "</div>"
      end
      if part.face_count > 0
        tt += "<div class=\"tt-section\">"
          tt += "<div><i class=\"ladb-opencutlist-icon-face-01\"></i>&nbsp;#{CGI::escape_html(part.face_material_names[:zmin])}&nbsp;<small>#{CGI::escape_html(part.face_std_dimensions[:zmin])}</small></div>" if part.face_material_names[:zmin]
          tt += "<div><i class=\"ladb-opencutlist-icon-face-10\"></i>&nbsp;#{CGI::escape_html(part.face_material_names[:zmax])}&nbsp;<small>#{CGI::escape_html(part.face_std_dimensions[:zmax])}</small></div>" if part.face_material_names[:zmax]
        tt += "</div>"
      end
      tt
    end

    def _render_leftover_def_tooltip(leftover_def)
      tt = "<div class=\"tt-header\"><span class=\"tt-name\">#{PLUGIN.get_i18n_string('tab.cutlist.packing.list.leftovers_to_keep')}</span></div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-size-length-width\"></i> #{CGI::escape_html(leftover_def.length.to_s)}&nbsp;x&nbsp;#{CGI::escape_html(leftover_def.width.to_s)}</div>"
      tt
    end

    def _render_cut_def_tooltip(cut_def)
      tt = "<div class=\"tt-header\"><span class=\"tt-name\">#{PLUGIN.get_i18n_string("tab.cutlist.packing.list.cut#{(cut_def.depth == 0 ? '_trimming' : (cut_def.depth == 1 ? '_primary' : ''))}")}</span></div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-vertical-cut-#{@origin_corner == ORIGIN_CORNER_BOTTOM_LEFT || @origin_corner == ORIGIN_CORNER_TOP_LEFT ? 'right' : 'left'}\"></i> #{CGI::escape_html(cut_def.x.to_s)}</div>" if cut_def.vertical?
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-horizontal-cut-#{@origin_corner == ORIGIN_CORNER_BOTTOM_LEFT || @origin_corner == ORIGIN_CORNER_BOTTOM_RIGHT ? 'top' : 'bottom'}\"></i> #{CGI::escape_html(cut_def.y.to_s)}</div>" if cut_def.horizontal?
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-#{cut_def.vertical? ? 'height' : 'width'}\"></i> #{CGI::escape_html(cut_def.length.to_s)}</div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-saw\"></i> #{CGI::escape_html(DimensionUtils.str_add_units(@spacing.to_l.to_s))}</div>"
      tt
    end

    def _render_bin_max_tooltip(max, icon)
      "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-#{icon}\"></i> #{CGI::escape_html(max.to_s)}</div>"
    end

    def _compute_text_size(text:, font: 'helvetica', size:, align: TextAlignLeft)
      if Sketchup.version_number < 2000000000 || Sketchup.active_model.nil?
        # Estimate letter width
        width = text.length * size.to_i * 0.6
      else
        text_bounds = Sketchup.active_model.active_view.text_bounds(Geom::Point3d.new, text, {
          :font => font,
          :size => size,
          :align => align,
          :bold => false
        })
        width = text_bounds.width
      end
      [ width, size ]
    end

    # -----

    BinTypeDef = Struct.new(:id, :length, :width, :count, :cost, :std_price, :type)
    ItemTypeDef = Struct.new(:length, :width, :count, :part, :projection_def, :color)

  end

end
