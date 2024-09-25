module Ladb::OpenCutList

  require 'json'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/packy/packy'
  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../model/packing/packing_def'

  class CutlistPackingWorker

    include PartDrawingHelper
    include PixelConverterHelper

    Packy = Fiddle::Packy

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
                   scrap_bin_sizes: '',

                   problem_type: Packy::PROBLEM_TYPE_RECTANGLE,
                   optimization_mode: 'not-anytime',
                   objective: 'bin-packing',
                   spacing: '20mm',
                   trimming: '10mm',
                   time_limit: 20,
                   not_anytime_tree_search_queue_size: 16,
                   verbosity_level: 0,

                   rectangleguillotine_cut_type: 'exact',
                   rectangleguillotine_first_stage_orientation: 'horizontal',

                   irregular_allowed_rotations: '0',
                   irregular_allow_mirroring: false

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids
      @std_bin_sizes = DimensionUtils.instance.dxd_to_ifloats(std_bin_sizes)
      @scrap_bin_sizes = DimensionUtils.instance.dxdxq_to_ifloats(scrap_bin_sizes)

      @problem_type = problem_type
      @optimization_mode = optimization_mode
      @objective = objective
      @spacing = DimensionUtils.instance.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(trimming).to_l.to_f
      @time_limit = [ 1 , time_limit.to_i ].max
      @not_anytime_tree_search_queue_size = [ 1 , not_anytime_tree_search_queue_size.to_i ].max
      @verbosity_level = verbosity_level.to_i

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
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
        @scrap_bin_sizes.split(';').each do |scrap_bin_size|

          ddq = scrap_bin_size.split('x')
          length = ddq[0].strip.to_l.to_f
          width = ddq[1].strip.to_l.to_f
          copies = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max

          next if length == 0 || width == 0 || copies == 0

          bin_type = {
            copies: copies,
            width: _to_packy(length),
            height: _to_packy(width),
          }
          if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
            bin_type[:left_trim] = bin_type[:right_trim] = bin_type[:bottom_trim] = bin_type[:top_trim] = _to_packy(@trimming)
          elsif @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
            bin_type[:type] = 'rectangle'
          end
          bin_types << bin_type
          @bin_type_defs << BinTypeDef.new(length, width, 1) # 1 = user defined

        end

        # Create bins from std sheets
        @std_bin_sizes.split(';').each do |std_bin_size|

          dd = std_bin_size.split('x')
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
          @bin_type_defs << BinTypeDef.new(length, width, 0) # 0 = Standard

        end

        return { :errors => [ 'tab.cutlist.cuttingdiagram.error.no_sheet' ] } if bin_types.empty?

        item_types = []

        # Add items from parts
        fn_add_items = lambda { |part|

          projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part, compute_shell: true)

          if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR

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

            item_types << {
              copies: part.count,
              width: _to_packy(part.def.cutting_size.length),
              height: _to_packy(part.def.cutting_size.width),
              oriented: (group.material_grained && !part.ignore_grain_direction) ? true : false
            }

          end

          @item_type_defs << ItemTypeDef.new(projection_def, part, ColorUtils.color_lighten(ColorUtils.color_create("##{Digest::SHA1.hexdigest(part.number.to_s)[0..5]}"), 0.8))

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

        return { :errors => [ 'tab.cutlist.cuttingdiagram.error.no_parts' ] } if item_types.empty?

        instance_parameters = {}
        if @problem_type == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE
          instance_parameters = {
            cut_type: @rectangleguillotine_cut_type,
            cut_thickness: _to_packy(@spacing),
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

      return output if output['running'] || output['cancelled']

      if @verbosity_level > 0
        puts ' '
        puts '-- output --'
        puts output.to_json
        puts '-- output --'
      end

      return { :errors => [ output['error'] ] } if output.has_key?('error')
      return { :errors => [ 'tab.cutlist.cuttingdiagram.error.no_placement_possible_2d' ] } if output['bins'].nil? || output['bins'].empty?

      packing_def = PackingDef.new(
        PackingOptionsDef.new(
          @problem_type,
          @spacing,
          @trimming
        ),
        PackingSummaryDef.new(
          output['time'],
          output['number_of_bins'],
          output['number_of_different_bins'],
          output['cost'],
          output['number_of_items'],
          output['profit'],
          output['efficiency']
        ),
        output['bins'].map { |raw_bin|
          bin_type_def = @bin_type_defs[raw_bin['bin_type_id']]
          PackingBinDef.new(
            bin_type_def,
            raw_bin['copies'],
            raw_bin['efficiency'],
            raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
              PackingItemDef.new(
                @item_type_defs[raw_item['item_type_id']],
                _from_packy(raw_item.fetch('x', 0)).to_l,
                _from_packy(raw_item.fetch('y', 0)).to_l,
                raw_item.fetch('angle', 0),
                raw_item.fetch('mirror', false)
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
            }.sort_by { |cut_def| cut_def.depth } : []
          )
        }.sort_by { |bin_def| [ -bin_def.bin_type_def.type, bin_def.bin_type_def.length, -bin_def.efficiency, -bin_def.copies ] }
      )

      packing_def.bin_defs.each do |bin_def|
        bin_def.svg = _render_bin_def_svg(bin_def)
        bin_def.total_cut_length = bin_def.cut_defs.sum { |cut_def| cut_def.length }
      end

      packing_def.create_packing.to_hash
    end

    def _to_packy(l)
      return l.to_f.round(8) if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      (l.to_l.to_mm * 10.0).to_i
    end

    def _from_packy(l)
      return l if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      l.mm / 10.0
    end

    def _render_bin_def_svg(bin_def,
                            display_projection: true
    )

      is_1d = @problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL
      is_2d = !is_1d
      is_irregular = @problem_type == Packy::PROBLEM_TYPE_IRREGULAR

      px_bin_dimension_font_size = 16
      px_item_dimension_font_size = 12
      px_item_number_font_size = 26
      px_item_number_font_size_min = 8

      px_bin_dimension_offset = 10
      px_item_dimension_offset = 3
      px_leftover_bullet_offset = 10

      px_bin_outline_width = 1
      px_item_outline_width = 2
      px_cut_outline_width = 2
      px_edge_width = 2

      max_bin_length = bin_def.bin_type_def.length # TODO

      px_bin_length = _to_px(bin_def.bin_type_def.length)
      px_bin_width = _to_px(bin_def.bin_type_def.width)
      px_trimming = _to_px(@trimming)

      vb_offset_x = (max_bin_length - px_bin_length) / 2
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
        svg += "</defs>"
        svg += "<text class='bin-dimension' x='#{px_bin_length / 2}' y='-#{px_bin_outline_width + px_bin_dimension_offset}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic'>#{bin_def.bin_type_def.length.to_l}</text>"
        svg += "<text class='bin-dimension' x='-#{px_bin_outline_width + px_bin_dimension_offset}' y='#{px_bin_width / 2}' font-size='#{px_bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic' transform='rotate(-90 -#{px_bin_outline_width + px_bin_dimension_offset},#{px_bin_width / 2})'>#{bin_def.bin_type_def.width.to_l}</text>"
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

          px_item_x = _to_px(item_def.x)
          px_item_y = px_bin_width - _to_px(item_def.y)
          px_item_length = _to_px(part.def.cutting_size.length)
          px_item_width = _to_px(is_1d ? bin_def.bin_type_def.width : part.def.cutting_size.width)

          svg += "<g class='item' transform='translate(#{px_item_x} #{px_item_y}) rotate(-#{item_def.angle})#{' scale(-1 1)' if item_def.mirror}' data-toggle='tooltip' data-html='true' title='<div>#{part.name}</div><div>x = #{item_def.x}</div><div>y = #{item_def.y}</div>'>"
            svg += "<rect class='item-outer' x='0' y='-#{px_item_width}' width='#{px_item_length}' height='#{px_item_width}' />" unless is_irregular
            if display_projection && !projection_def.nil?
              svg += "<g class='item-projection'#{" transform='translate(#{_to_px((part.def.cutting_size.length - part.def.size.length) / 2)} -#{_to_px((part.def.cutting_size.width - part.def.size.width) / 2)})'" unless is_irregular}>"
                svg += "<path stroke='black' fill='#{ColorUtils.color_to_hex(item_type_def.color)}' stroke-width='0.5' class='item-projection-shape' d='#{projection_def.layer_defs.map { |layer_def| "#{layer_def.poly_defs.map { |poly_def| "M #{(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points).map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}" }.join(' ')}' />"
              svg += '</g>'
            end
            unless is_irregular
              if is_2d
                svg += "<text class='item-dimension' x='#{px_item_length - px_item_dimension_offset}' y='-#{px_item_width - px_item_dimension_offset}' font-size='#{px_item_dimension_font_size}' text-anchor='end' dominant-baseline='hanging'>#{part.cutting_length.gsub(/~ /, '')}</text>"
                svg += "<text class='item-dimension' x='#{px_item_dimension_offset}' y='-#{px_item_dimension_offset}' font-size='#{px_item_dimension_font_size}' text-anchor='start' dominant-baseline='hanging' transform='rotate(-90 #{px_item_dimension_offset} -#{px_item_dimension_offset})'>#{part.cutting_width.gsub(/~ /, '')}</text>"
              elsif is_1d
                svg += "<text class='item-dimension' x='#{px_item_length / 2}' y='#{px_bin_dimension_offset}' font-size='#{px_item_dimension_font_size}' text-anchor='middle' dominant-baseline='hanging'>#{part.cutting_length.gsub(/~ /, '')}</text>"
              end
            end
            svg += "<text class='item-number' x='#{px_item_length / 2}' y='-#{px_item_width / 2}' font-size='#{[ px_item_number_font_size, [ px_item_width * 0.8 , 6 ].max ].min}' text-anchor='middle' dominant-baseline='central'>#{part.number}</text>"
          svg += '</g>'

        end
      bin_def.cut_defs.each do |cut_def|

          px_cut_x = _to_px(cut_def.x)
          px_cut_y = px_bin_width - _to_px(cut_def.y)
          px_cut_length = _to_px(cut_def.length)
          px_cut_width = [ 1, _to_px(@spacing) ].max

          if cut_def.orientation == 'horizontal'
            px_rect_width = px_cut_length
            px_rect_height = px_cut_width
          else
            px_rect_width = px_cut_width
            px_rect_height = px_cut_length
          end
          px_rect_y = px_cut_y - px_rect_height

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

          svg += "<g class='cut#{clazz}' data-toggle='tooltip' title='depth = #{cut_def.depth}'>"
            svg += "<rect class='cut-outer' x='#{px_cut_x - px_cut_outline_width}' y='#{px_rect_y - px_cut_outline_width}' width='#{px_rect_width + px_cut_outline_width * 2}' height='#{px_rect_height + px_cut_outline_width * 2}' />"
            svg += "<rect class='cut-inner' x='#{px_cut_x}' y='#{px_rect_y}' width='#{px_rect_width}' height='#{px_rect_height}' />"
          svg += "</g>"

        end
      svg += '</svg>'

      svg
    end

    # -----

    BinTypeDef = Struct.new(:length, :width, :type)
    ItemTypeDef = Struct.new(:projection_def, :part, :color)

  end

end
