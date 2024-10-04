module Ladb::OpenCutList

  require 'json'
  require 'cgi'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/packy/packy'
  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../model/packing/packing_def'
  require_relative '../../model/export/wrappers'


  class CutlistPackingWorker

    include PartDrawingHelper
    include PixelConverterHelper

    Packy = Fiddle::Packy

    ORIGIN_CORNER_TOP_LEFT = 0
    ORIGIN_CORNER_BOTTOM_LEFT = 1
    ORIGIN_CORNER_TOP_RIGHT = 2
    ORIGIN_CORNER_BOTTOM_RIGHT = 3

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
      ],
      "45" => [
        { start: 0, end: 0 },
        { start: 45, end: 45 },
        { start: 90, end: 90 },
        { start: 135, end: 135 },
        { start: 180, end: 180 },
        { start: 22, end: 225 },
        { start: 270, end: 270 },
        { start: 315, end: 315 },
      ]
    }

    def initialize(cutlist,

                   group_id:,
                   part_ids: nil,

                   std_bin_sizes: '',
                   scrap_bin_1d_sizes: '',
                   scrap_bin_2d_sizes: '',

                   problem_type: Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE,
                   optimization_mode: 'not-anytime',
                   objective: 'bin-packing',
                   spacing: '20mm',
                   trimming: '10mm',
                   time_limit: 20,
                   not_anytime_tree_search_queue_size: 16,
                   verbosity_level: 0,

                   items_formula: '',
                   hide_part_list: false,
                   part_drawing_type: PART_DRAWING_TYPE_NONE,
                   colored_part: true,
                   origin_corner: ORIGIN_CORNER_TOP_LEFT,

                   rectangleguillotine_cut_type: 'exact',
                   rectangleguillotine_number_of_stages: 3,
                   rectangleguillotine_first_stage_orientation: 'horizontal',

                   irregular_allowed_rotations: '0',
                   irregular_allow_mirroring: false

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids

      @std_bin_sizes = DimensionUtils.dxd_to_ifloats(std_bin_sizes)
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
      @colored_part = colored_part
      @origin_corner = origin_corner.to_i

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
      @rectangleguillotine_number_of_stages = [ [ 2, rectangleguillotine_number_of_stages.to_i ].max, 3 ].min
      @rectangleguillotine_first_stage_orientation = rectangleguillotine_first_stage_orientation

      @irregular_allowed_rotations = AVAILABLE_ROTATIONS.fetch(irregular_allowed_rotations.to_s, [])
      @irregular_allow_mirroring = irregular_allow_mirroring

      # Internals

      @_running = false
      @bin_type_defs = []
      @item_type_defs = []

    end

    # -----

    def run(action)
      case action
      when :start

        return { :errors => [ 'default.error' ] } if @_running
        return { :errors => [ 'default.error' ] } unless @cutlist

        model = Sketchup.active_model
        return{ :errors => [ 'default.error' ] } unless model

        group = @cutlist.get_group(@group_id)
        return { :errors => [ 'default.error' ] } unless group

        parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids)
        return { :errors => [ 'default.error' ] } if parts.empty?

        parts_count = parts.map(&:count).inject(0, :+)  # .map(&:count).inject(0, :+) == .sum { |portion| part.count } compatible with ruby < 2.4

        bin_types = []

        # Create bins from scrap sheets
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

          bin_type = {
            copies: count,
            width: _to_packy(length),
            height: _to_packy(width),
          }
          if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
            bin_type[:left_trim] = bin_type[:right_trim] = bin_type[:bottom_trim] = bin_type[:top_trim] = _to_packy(@trimming)
          elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
            bin_type[:type] = 'rectangle'
          end
          bin_types << bin_type
          @bin_type_defs << BinTypeDef.new(Digest::MD5.hexdigest("#{length}_#{width}_1"), length, width, count, 1) # 1 = user defined

        end

        # Create bins from std sheets
        @std_bin_sizes.split(DimensionUtils::LIST_SEPARATOR).each do |std_bin_size|

          dd = std_bin_size.split(DimensionUtils::DXD_SEPARATOR)
          length = dd[0].strip.to_l.to_f
          width = dd[1].strip.to_l.to_f

          next if length == 0 || width == 0

          bin_type = {
            copies: parts_count,
            width: _to_packy(length),
            height: _to_packy(width),
          }
          if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
            bin_type[:left_trim] = bin_type[:right_trim] = bin_type[:bottom_trim] = bin_type[:top_trim] = _to_packy(@trimming)
          elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
            bin_type[:type] = 'rectangle'
          end
          bin_types << bin_type
          @bin_type_defs << BinTypeDef.new(Digest::MD5.hexdigest("#{length}_#{width}_0"), length, width, -1, 0) # 0 = Standard

        end

        return { :errors => [ "tab.cutlist.packing.error.no_bin_#{group.material_is_1d ? '1d' : '2d'}" ] } if bin_types.empty?

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
                vertices: shape_def.outer_poly_def.points.map { |point| { x: _to_packy(point.x), y: _to_packy(point.y) } },
                holes: shape_def.holes_poly_defs.map { |poly_def| {
                  type: 'polygon',
                  vertices: poly_def.points.map { |point| { x: _to_packy(point.x), y: _to_packy(point.y) } }
                }},
              }},
              allowed_rotations: @irregular_allowed_rotations,
              allow_mirroring: @irregular_allow_mirroring
            }

          else

            length = part.def.cutting_size.length
            width = part.def.cutting_size.width

            item_types << {
              copies: count,
              width: _to_packy(length),
              height: _to_packy(width),
              oriented: (group.material_grained && !part.ignore_grain_direction) ? true : false
            }

          end

          @item_type_defs << ItemTypeDef.new(length, width, count, part, projection_def, @colored_part ? ColorUtils.color_lighten(ColorUtils.color_create("##{Digest::SHA1.hexdigest(part.number.to_s)[0..5]}"), 0.8) : nil)

        }
        parts.each { |part|
          if part.instance_of?(FolderPart)
            part.children.each { |child_part|
              fn_add_items.call(child_part)
            }
          else
            fn_add_items.call(part)
          end
        }

        return { :errors => [ 'tab.cutlist.packing.error.no_part' ] } if item_types.empty?

        instance_parameters = {}
        if @problem_type == Packy::PROBLEM_TYPE_RECTANGLE || @problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL
          instance_parameters = {
            fake_trimming: _to_packy(@trimming),
            fake_spacing: _to_packy(@spacing)
          }
          elsif @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
          instance_parameters = {
            cut_type: @rectangleguillotine_cut_type,
            cut_thickness: _to_packy(@spacing),
            number_of_stages: @rectangleguillotine_number_of_stages,
            first_stage_orientation: @rectangleguillotine_first_stage_orientation,
          }
        elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
          instance_parameters = {
            item_bin_minimum_spacing: _to_packy(@trimming),
            item_item_minimum_spacing: _to_packy(@spacing)
          }
        end

        input = {
          problem_type: @problem_type,
          parameters: {
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
        if @verbosity_level > 1
          puts ' '
          puts '-- instance --'
          puts input[:instance].to_json
          puts '-- instance --'
        end

        output = Packy.optimize_start(input)

        @_running = true

        return _process_ouput(output)

      when :advance

        return { :errors => [ 'default.error' ] } unless @_running

        output = Packy.optimize_advance

        return _process_ouput(output)

      when :cancel

        return { :errors => [ 'default.error' ] } unless @_running

        Packy.optimize_cancel

        return { :cancelled => true }
      end

      { :errors => [ 'default.error' ] }
    end

    private

    def _process_ouput(output)

      return output if output['cancelled']
      return output if output['running'] && output['solution'].nil?

      if @verbosity_level > 0
        puts ' '
        puts '-- output --'
        puts output.to_json
        puts '-- output --'
      end

      return { :errors => [ [ 'core.error.extern', { 'error' => output['error'] } ] ] } if output.has_key?('error')

      solution = output['solution']

      return { :errors => [ 'tab.cutlist.packing.error.no_solution' ] } if solution['bins'].nil? || solution['bins'].empty?

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
        PackingOptionsDef.new(
          @problem_type,
          @spacing,
          @trimming,
          @hide_part_list,
          @part_drawing_type
        ),
        PackingSummaryDef.new(
          solution['time'],
          solution['number_of_bins'],
          solution['number_of_items'],
          solution['efficiency']
        ),
        solution['bins'].map { |raw_bin|
          bin_type_def = @bin_type_defs[raw_bin['bin_type_id']]
          PackingBinDef.new(
            bin_type_def,
            raw_bin['copies'],
            raw_bin['efficiency'],
            raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
              item_type_def = @item_type_defs[raw_item['item_type_id']]
              PackingItemDef.new(
                item_type_def,
                instance_info_by_item_type_def[item_type_def].is_a?(Array) ? instance_info_by_item_type_def[item_type_def].shift : nil,
                _from_packy(raw_item.fetch('x', 0)).to_l,
                _from_packy(raw_item.fetch('y', 0)).to_l,
                raw_item.fetch('angle', 0),
                raw_item.fetch('mirror', false)
              )
            } : [],
            raw_bin['leftovers'].is_a?(Array) ? raw_bin['leftovers'].map { |raw_leftover|
              PackingLeftoverDef.new(
                _from_packy(raw_leftover.fetch('x', 0)).to_l,
                _from_packy(raw_leftover.fetch('y', 0)).to_l,
                _from_packy(raw_leftover.fetch('width', 0)).to_l,
                _from_packy(raw_leftover.fetch('height', 0)).to_l
              )
            } : [],
            raw_bin['cuts'].is_a?(Array) ? raw_bin['cuts'].map { |raw_cut|
              PackingCutDef.new(
                raw_cut['depth'],
                _from_packy(raw_cut.fetch('x', 0)).to_l,
                _from_packy(raw_cut.fetch('y', 0)).to_l,
                (raw_cut['length'] ? _from_packy(raw_cut['length']) : bin_type_def.width).to_l,
                raw_cut.fetch('orientation', 'vertical'),
                )
            }.sort_by { |cut_def| cut_def.depth } : [],
            raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
              @item_type_defs[raw_item['item_type_id']]
            }.group_by { |i| i }.map { |item_type_def, v|
              PackingBinPartDef.new(
                item_type_def.part,
                v.length
              )
            }.sort_by { |bin_part_def| bin_part_def._sorter } : []
          )
        }.sort_by { |bin_def| [ -bin_def.bin_type_def.type, bin_def.bin_type_def.length, -bin_def.efficiency, -bin_def.count ] }
      )

      # Computed values

      bin_type_uses = @bin_type_defs.map { |bin_type_def| [ bin_type_def, [ 0, 0 ] ] }.to_h

      packing_def.bin_defs.each do |bin_def|

        bin_type_uses[bin_def.bin_type_def][0] += bin_def.count                             # used_count
        bin_type_uses[bin_def.bin_type_def][1] += bin_def.count * bin_def.item_defs.length  # total_item_count

        bin_def.svg = _render_bin_def_svg(bin_def, output['running'])
        bin_def.total_cut_length = bin_def.cut_defs.map(&:length).inject(0, :+)  # .map(&:length).inject(0, :+) == .sum { |bin_def| bin_def.length } compatible with ruby < 2.4

        packing_def.summary_def.total_leftover_count += bin_def.leftover_defs.length
        packing_def.summary_def.total_cut_count += bin_def.cut_defs.length
        packing_def.summary_def.total_cut_length += bin_def.total_cut_length

      end

      bin_type_uses.each do |bin_type_def, counters|

        used_count, total_item_count = counters
        unused_count = bin_type_def.count < 0 ? 0 : bin_type_def.count - used_count

        if unused_count > 0
          packing_def.summary_def.bin_type_defs << PackingSummaryBinTypeDef.new(bin_type_def, unused_count, false)
        end

        if used_count > 0
          packing_def.summary_def.bin_type_defs << PackingSummaryBinTypeDef.new(bin_type_def, used_count, true, total_item_count)
          packing_def.summary_def.total_used_count += used_count
          packing_def.summary_def.total_used_area += packing_def.summary_def.bin_type_defs.last.total_area
          packing_def.summary_def.total_used_length += packing_def.summary_def.bin_type_defs.last.total_length
          packing_def.summary_def.total_used_item_count += total_item_count
        end

      end
      packing_def.summary_def.bin_type_defs.sort_by!{ |bin_type_def| [ bin_type_def.used ? 1 : 0, -bin_type_def.bin_type_def.type, bin_type_def.bin_type_def.length ]}

      {
        :running => output['running'],
        :solution => packing_def.create_packing.to_hash
      }
    end

    def _to_packy(l)
      return l.to_f.round(8) if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      (l.to_l.to_mm * 10.0).to_i
    end

    def _from_packy(l)
      return l if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      l.mm / 10.0
    end

    def _render_bin_def_svg(bin_def, running)

      px_bin_dimension_font_size = 16
      px_item_dimension_font_size = 12
      px_leftover_dimension_font_size = 12
      px_item_number_font_size_max = 24
      px_item_number_font_size_min = 8

      px_bin_dimension_offset = 10
      px_item_dimension_offset = 3
      px_leftover_dimension_offset = 3
      px_leftover_bullet_offset = 10

      px_bin_outline_width = 1
      px_item_outline_width = 2
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
      is_cut_lg = px_spacing >= 3

      vb_offset_x = (px_max_bin_length - px_bin_length) / 2
      vb_x = (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size + vb_offset_x) * -1
      vb_y = (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size) * -1
      vb_width = px_bin_length + (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size + vb_offset_x) * 2
      vb_height = px_bin_width + (px_bin_outline_width + px_bin_dimension_offset + px_bin_dimension_font_size) * 2

      svg = "<svg viewbox='#{vb_x} #{vb_y} #{vb_width} #{vb_height}' style='max-height: #{vb_height}px' class='problem-type-#{@problem_type}'>"
        svg += "<defs>"
          svg += "<pattern id='pattern_bin_bg' width='10' height='10' patternUnits='userSpaceOnUse'>"
            svg += "<rect x='0' y='0' width='10' height='10' fill='white' />"
            svg += "<path d='M0,10L10,0' style='fill:none;stroke:#ddd;stroke-width:0.5px;'/>"
          svg += "</pattern>"
          if is_cut_lg
            svg += "<pattern id='pattern_cut_bg' width='5' height='5' patternUnits='userSpaceOnUse'>"
              svg += "<rect x='0' y='0' width='5' height='5' fill='white'/>"
              svg += "<path d='M0,5L5,0' style='fill:none;stroke:#000;stroke-width:0.5px;'/>"
            svg += "</pattern>"
          end
        svg += "</defs>"
        unless running
          svg += "<text class='bin-dimension' x='#{px_bin_length / 2}' y='#{-(px_bin_outline_width + px_bin_dimension_offset)}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic'>#{bin_def.bin_type_def.length.to_l}</text>"
          svg += "<text class='bin-dimension' x='#{-(px_bin_outline_width + px_bin_dimension_offset)}' y='#{px_bin_width / 2}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic' transform='rotate(-90 -#{px_bin_outline_width + px_bin_dimension_offset},#{px_bin_width / 2})'>#{bin_def.bin_type_def.width.to_l}</text>"
        end
        svg += "<g class='bin'>"
          svg += "<rect class='bin-outer' x='-1' y='-1' width='#{px_bin_length + 2}' height='#{px_bin_width + 2}' />"
          svg += "<rect class='bin-inner' x='0' y='0' width='#{px_bin_length}' height='#{px_bin_width}' fill='url(#pattern_bin_bg)'/>"
          if is_1d
            svg += "<line class='bin-trimming' x1='#{px_trimming}' y1='0' x2='#{px_trimming}' y2='#{px_bin_width}' stroke='#ddd' stroke-dasharray='4'/>" if @trimming > 0
            svg += "<line class='bin-trimming' x1='#{px_bin_length - px_trimming}' y1='0' x2='#{px_bin_length - px_trimming}' y2='#{px_bin_width}' stroke='#ddd' stroke-dasharray='4'/>" if @trimming > 0
          elsif is_2d
            svg += "<rect class='bin-trimming' x='#{px_trimming}' y='#{px_trimming}' width='#{px_bin_length - px_trimming * 2}' height='#{px_bin_width - px_trimming * 2}' fill='none' stroke='#ddd' stroke-dasharray='4'/>" if @trimming > 0
          end
        svg += '</g>'
        bin_def.item_defs.each do |item_def|

          item_type_def = item_def.item_type_def
          projection_def = item_type_def.projection_def
          part = item_type_def.part

          item_text = _evaluate_item_text(part, item_def.instance_info)
          item_text = "<tspan data-toggle='tooltip' title='#{CGI::escape_html(item_text[:error])}' fill='red'>!!</tspan>" if item_text.is_a?(Hash)

          px_item_length = _to_px(item_type_def.length)
          px_item_width = is_1d ? px_bin_width : _to_px(item_type_def.width)
          px_item_x = _to_px(item_def.x)
          px_item_y = _to_px(item_def.y)

          px_part_length = _to_px(part.def.size.length)
          px_part_width = _to_px(part.def.size.width)

          t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, item_def.angle.degrees)
          t *= Geom::Transformation.scaling(-1.0, 1.0, 1.0) if item_def.mirror
          pts = [
            Geom::Point3d.new(0, 0),
            Geom::Point3d.new(px_item_length, 0),
            Geom::Point3d.new(px_item_length, px_item_width),
            Geom::Point3d.new(0, px_item_width),
          ]
          pts.each { |pt| pt.transform!(t) }
          bounds = Geom::BoundingBox.new
          bounds.add(pts)

          px_item_rect_width = bounds.width.to_f
          px_item_rect_height = bounds.height.to_f
          px_item_rect_x = _compute_x_with_origin_corner(px_item_x + bounds.min.x.to_f, px_item_rect_width, px_bin_length)
          px_item_rect_y = px_bin_width - _compute_y_with_origin_corner(px_item_y + bounds.min.y.to_f, px_item_rect_height, px_bin_width)

          svg += "<g class='item' transform='translate(#{px_item_rect_x} #{px_item_rect_y})' data-toggle='tooltip' data-html='true' title='#{_render_item_def_tooltip(item_def)}' data-part-id='#{part.id}'>"
            svg += "<rect class='item-outer' x='0' y='#{-px_item_rect_height}' width='#{px_item_rect_width}' height='#{px_item_rect_height}'#{" fill='#eee' stroke='#555'" if running}/>" unless is_irregular

            unless @part_drawing_type == PART_DRAWING_TYPE_NONE || projection_def.nil?
              svg += "<g class='item-projection' transform='translate(#{px_item_rect_width / 2} #{-px_item_rect_height / 2})#{' scale(-1 1)' if item_def.mirror}  rotate(#{-item_def.angle}) translate(#{-px_part_length / 2} #{px_part_width / 2})'>"
                svg += "<path stroke='#{@colored_part && !is_irregular ? ColorUtils.color_to_hex(ColorUtils.color_darken(item_type_def.color, 0.4)) : '#000'}' fill='#{@colored_part ? ColorUtils.color_to_hex(item_type_def.color) : '#eee'}' stroke-width='0.5' class='item-projection-shape' d='#{projection_def.layer_defs.map { |layer_def| "#{layer_def.poly_defs.map { |poly_def| "M #{(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points).map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}" }.join(' ')}' />"
              svg += '</g>'
            end

            unless running
              unless is_irregular
                if is_2d
                  svg += "<text class='item-dimension' x='#{px_item_rect_width - px_item_dimension_offset}' y='#{-(px_item_rect_height - px_item_dimension_offset)}' font-size='#{px_item_dimension_font_size}' text-anchor='end' dominant-baseline='hanging'>#{part.cutting_length.gsub(/~ /, '')}</text>"
                  svg += "<text class='item-dimension' x='#{px_item_dimension_offset}' y='#{-px_item_dimension_offset}' font-size='#{px_item_dimension_font_size}' text-anchor='start' dominant-baseline='hanging' transform='rotate(-90 #{px_item_dimension_offset} -#{px_item_dimension_offset})'>#{part.cutting_width.gsub(/~ /, '')}</text>"
                elsif is_1d
                  svg += "<text class='item-dimension' x='#{px_item_rect_width / 2}' y='#{px_bin_dimension_offset}' font-size='#{px_item_dimension_font_size}' text-anchor='middle' dominant-baseline='hanging'>#{part.cutting_length.gsub(/~ /, '')}</text>"
                end
              end

              svg += "<text class='item-number' x='0' y='0' font-size='#{[ [ px_item_number_font_size_max, px_item_width / 2, px_item_length / (item_text.length * 0.6) ].min, px_item_number_font_size_min ].max}' text-anchor='middle' dominant-baseline='central' transform='translate(#{px_item_rect_width / 2} #{-px_item_rect_height / 2}) rotate(#{-(item_def.angle % 180)})'>#{item_text}</text>"
            end

          svg += "</g>"

        end
        unless running
          bin_def.leftover_defs.each do |leftover_def|

          px_leftover_length = _to_px(leftover_def.length)
          px_leftover_width = is_1d ? px_bin_width : _to_px(leftover_def.width)
          px_leftover_x = _compute_x_with_origin_corner(_to_px(leftover_def.x), px_leftover_length, px_bin_length)
          px_leftover_y = px_bin_width - _compute_y_with_origin_corner(_to_px(leftover_def.y), px_leftover_width, px_bin_width)

          length_text = leftover_def.length.to_s.gsub(/~ /, '')
          width_text = leftover_def.width.to_s.gsub(/~ /, '')

          px_length_text_length = length_text.length * px_leftover_dimension_font_size * 0.7
          px_width_text_length = length_text.length * px_leftover_dimension_font_size * 0.7

          svg += "<g class='leftover' transform='translate(#{px_leftover_x} #{px_leftover_y})'>"
            svg += "<rect x='0' y='#{-px_leftover_width}' width='#{px_leftover_length}' height='#{px_leftover_width}'/>"
            if is_2d
              svg += "<text class='leftover-dimension' x='#{px_leftover_length - px_leftover_dimension_offset}' y='#{-(px_leftover_width - px_leftover_dimension_offset)}' font-size='#{px_leftover_dimension_font_size}' text-anchor='end' dominant-baseline='hanging'>#{length_text}</text>" if px_leftover_length > px_length_text_length && px_leftover_width > px_leftover_dimension_font_size
              svg += "<text class='leftover-dimension' x='#{px_leftover_dimension_offset}' y='#{-px_leftover_dimension_offset}' font-size='#{px_leftover_dimension_font_size}' text-anchor='start' dominant-baseline='hanging' transform='rotate(-90 #{px_leftover_dimension_offset} -#{px_leftover_dimension_offset})'>#{width_text}</text>" if px_leftover_length > px_leftover_dimension_font_size && px_leftover_width > px_width_text_length
            elsif is_1d
              svg += "<text class='leftover-dimension' x='#{px_leftover_length / 2}' y='#{px_bin_dimension_offset}' font-size='#{px_leftover_dimension_font_size}' text-anchor='middle' dominant-baseline='hanging'>#{leftover_def.length.to_s.gsub(/~ /, '')}</text>"
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
          px_cut_rect_x = _compute_x_with_origin_corner(px_cut_x, px_cut_rect_width, px_bin_length)
          px_cut_rect_y = _compute_y_with_origin_corner(px_cut_y - px_cut_rect_height, px_cut_rect_height, px_bin_width)

          case cut_def.depth
          when 0
            clazz = ' cut-trimming'
          when 1
            clazz = ' cut-bounding'
          when 2
            clazz = ' cut-internal-through'
          else
            clazz = ''
          end
          clazz += ' cut-lg' if is_cut_lg

          svg += "<g class='cut#{clazz}' data-toggle='tooltip' data-html='true' title='#{_render_cut_def_tooltip(cut_def)}'>"
            svg += "<rect class='cut-outer' x='#{px_cut_rect_x - px_cut_outline_width}' y='#{px_cut_rect_y - px_cut_outline_width}' width='#{px_cut_rect_width + px_cut_outline_width * 2}' height='#{px_cut_rect_height + px_cut_outline_width * 2}' />"
            svg += "<rect class='cut-inner' x='#{px_cut_rect_x}' y='#{px_cut_rect_y}' width='#{px_cut_rect_width}' height='#{px_cut_rect_height}'#{" fill='url(#pattern_cut_bg)'" if is_cut_lg}/>"
          svg += "</g>"

          end
        end
      svg += '</svg>'

      svg
    end

    def _compute_x_with_origin_corner(x, x_size, x_translation)
      return x if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      case @origin_corner
      when ORIGIN_CORNER_TOP_RIGHT, ORIGIN_CORNER_BOTTOM_RIGHT
        x_translation - x - x_size
      else
        x
      end
    end

    def _compute_y_with_origin_corner(y, y_size, y_translation)
      return y if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      case @origin_corner
      when ORIGIN_CORNER_TOP_LEFT, ORIGIN_CORNER_TOP_RIGHT
        y_translation - y - y_size
      else
        y
      end
    end

    def _render_item_def_tooltip(item_def)
      part = item_def.item_type_def.part
      tt = "<div class=\"tt-header\"><span class=\"tt-number\">#{part.number}</span><span class=\"tt-name\">#{CGI::escape_html(part.name)}</span></div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-size-length-width\"></i> #{CGI::escape_html(part.cutting_length)}&nbsp;x&nbsp;#{CGI::escape_html(part.cutting_width)}</div>"
      tt
    end

    def _render_cut_def_tooltip(cut_def)
      tt = "<div class=\"tt-header\"><span class=\"tt-name\">#{PLUGIN.get_i18n_string("tab.cutlist.cuttingdiagram.list.cut#{(cut_def.depth == 0 ? '_trimming' : (cut_def.depth == 1 ? '_bounding' : (cut_def.depth == 2 ? '_internal_through' : '')))}")}</span></div>"
      tt += "<div class=\"tt-data\"><i class=\"ladb-opencutlist-icon-saw\"></i> #{CGI::escape_html(@spacing.to_l.to_s)}</div>"
      tt += "<div>depth = #{cut_def.depth}</div>"
      tt += "<div>x = #{cut_def.x}</div>" if cut_def.vertical?
      tt += "<div>y = #{cut_def.y}</div>" if cut_def.horizontal?
      tt
    end

    # -----

    def _evaluate_item_text(part, instance_info)

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
        text = eval(@items_formula, data.get_binding)
        text = text.export if text.is_a?(Wrapper)
        text = text.to_s if !text.is_a?(String) && text.respond_to?(:to_s)
      rescue Exception => e
        text = { :error => e.message.split(/cutlist_packing_worker[.]rb:\d+:/).last } # Remove path in exception message
      end

      text
    end

    # -----

    BinTypeDef = Struct.new(:id, :length, :width, :count, :type)
    ItemTypeDef = Struct.new(:length, :width, :count, :part, :projection_def, :color)

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

end
