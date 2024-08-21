module Ladb::OpenCutList

  require 'json'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/packy/packy'
  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'

  class CutlistPackingWorker

    include PartDrawingHelper
    include PixelConverterHelper

    Packy = Fiddle::Packy

    AVAILABLE_ROTATIONS = [
      # 0 = None
      [
        { start: 0 },
      ],
      # 1 = 180°
      [
        { start: 0 },
        { start: 180 },
      ],
      # 2 = 90°
      [
        { start: 0 },
        { start: 90 },
        { start: 180 },
        { start: 270 },
      ],
      # 3 = 45°
      [
        { start: 0 },
        { start: 45 },
        { start: 90 },
        { start: 135 },
        { start: 180 },
        { start: 225 },
        { start: 270 },
        { start: 315 },
      ]
    ]

    def initialize(cutlist,

                   group_id:,
                   part_ids: nil,
                   std_sheet: '',
                   scrap_sheet_sizes: '',

                   problem_type: Packy::PROBLEM_TYPE_RECTANGLE,
                   objective: 'bin-packing',
                   spacing: '20mm',
                   trimming: '10mm',
                   time_limit: 20,
                   not_anytime_tree_search_queue_size: 16,
                   verbosity_level: 1,

                   rectangleguillotine_cut_type: 'exact',
                   rectangleguillotine_first_stage_orientation: 'horizontal',

                   irregular_rotations: 0

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids
      s_length, s_width = StringUtils.split_dxd(std_sheet)
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(s_length).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(s_width).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxdxq_to_ifloats(scrap_sheet_sizes)

      @problem_type = problem_type
      @objective = objective
      @spacing = DimensionUtils.instance.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(trimming).to_l.to_f
      @time_limit = [ 1 , time_limit.to_i ].max
      @not_anytime_tree_search_queue_size = [ 2 , not_anytime_tree_search_queue_size.to_i ].max
      @verbosity_level = verbosity_level.to_i

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
      @rectangleguillotine_first_stage_orientation = rectangleguillotine_first_stage_orientation

      @irregular_rotations = [ 0, [ irregular_rotations.to_i, AVAILABLE_ROTATIONS.length - 1 ].min].max

      # Internals

      @_running = false
      @bin_defs = []
      @item_defs = []

    end

    # -----

    def run
      unless @_running

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
        @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|

          ddq = scrap_sheet_size.split('x')
          length = ddq[0].strip.to_l.to_f
          width = ddq[1].strip.to_l.to_f
          copies = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max

          bin_types << {
            copies: copies,
            type: 'rectangle',
            length: _to_packy(length),
            width: _to_packy(width),
            left_trim: _to_packy(@trimming),
            right_trim: _to_packy(@trimming),
            bottom_trim: _to_packy(@trimming),
            top_trim: _to_packy(@trimming)
          }
          @bin_defs << Packy::BinDef.new(length, width, 1) # 1 = user defined

        }

        # Create bins from std sheets
        if @std_sheet_width > 0 && @std_sheet_length > 0

          bin_types << {
            copies: parts_count,
            type: 'rectangle',
            length: _to_packy(@std_sheet_length),
            width: _to_packy(@std_sheet_width),
            left_trim: _to_packy(@trimming),
            right_trim: _to_packy(@trimming),
            bottom_trim: _to_packy(@trimming),
            top_trim: _to_packy(@trimming)
          }
          @bin_defs << Packy::BinDef.new(@std_sheet_length, @std_sheet_width, 0) # 0 = Standard

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
              allowed_rotations: AVAILABLE_ROTATIONS[@irregular_rotations]
            }

          else

            item_types << {
              copies: part.count,
              length: _to_packy(part.def.size.length),
              width: _to_packy(part.def.size.width),
              oriented: (group.material_grained && !part.ignore_grain_direction) ? true : false
            }

          end

          @item_defs << Packy::ItemDef.new(projection_def, part)

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

        input = {
          problem_type: @problem_type,
          parameters: {
            optimization_mode: "not-anytime",
            time_limit: @time_limit,
            not_anytime_tree_search_queue_size: @not_anytime_tree_search_queue_size,
            verbosity_level: @verbosity_level
          },
          instance: {
            objective: @objective,
            parameters: {
              cut_type: @rectangleguillotine_cut_type,
              cut_thickness: _to_packy(@spacing),
              first_stage_orientation: @rectangleguillotine_first_stage_orientation
            },
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

        Packy.optimize_start(input)

        @_running = true

        { :running => true }
      else

        output = Packy.optimize_advance

        return output if output.has_key?('running')

        if @verbosity_level > 0
          puts ' '
          puts '-- output --'
          puts output.to_json
          puts '-- output --'
        end

        return { :errors => [ output['error'] ] } if output.has_key?('error')
        return { :errors => [ 'tab.cutlist.cuttingdiagram.error.no_placement_possible_2d' ] } if output['bins'].empty?

        bins = output['bins'].map do |raw_bin|
          Packy::Bin.new(
            @bin_defs[raw_bin['bin_type_id']],
            raw_bin['copies'],
            raw_bin['items'].is_a?(Array) ? raw_bin['items'].map { |raw_item|
              Packy::Item.new(
                @item_defs[raw_item['item_type_id']],
                _from_packy(raw_item.fetch('x', 0)).to_l,
                _from_packy(raw_item.fetch('y', 0)).to_l,
                raw_item.fetch('angle', 0)
              )
            } : [],
            raw_bin['cuts'].is_a?(Array) ? raw_bin['cuts'].map { |raw_cut|
              Packy::Cut.new(
                raw_cut['depth'],
                _from_packy(raw_cut['x1']).to_l,
                _from_packy(raw_cut['y1']).to_l,
                _from_packy(raw_cut['x2']).to_l,
                _from_packy(raw_cut['y2']).to_l,
              )
            } : []
          )
        end

        {
          :summary => {
            :total_used_count =>output['number_of_bins']
          },
          :bins => bins.map { |bin| {
            count: bin.copies,
            length: bin.def.length.to_l.to_s,
            width: bin.def.width.to_l.to_s,
            type: bin.def.type,
            svg: _bin_to_svg(bin)
          } }
        }
      end
    end

    private

    def _to_packy(l)
      return l.round(8) if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      (l.to_l.to_mm * 10.0).to_i
    end

    def _from_packy(l)
      return l if @problem_type == Packy::PROBLEM_TYPE_IRREGULAR
      l.mm / 10.0
    end

    def _bin_to_svg(bin, bg_color = '#dddddd')

      bin_dimension_font_size = 16
      dimension_font_size = 12
      number_font_size = 26
      min_number_font_size = 8

      bin_dimension_offset = 10
      dimension_offset = 1
      leftover_bullet_offset = 10

      bin_outline_width = 1
      item_outline_width = 2
      cut_outline_width = 2
      edge_width = 2

      max_bin_length = bin.def.length # TODO

      px_bin_length = _to_px(bin.def.length)
      px_bin_width = _to_px(bin.def.width)

      vb_offset_x = (max_bin_length - px_bin_length) / 2
      vb_x = (bin_outline_width + bin_dimension_offset + bin_dimension_font_size + vb_offset_x) * -1
      vb_y = (bin_outline_width + bin_dimension_offset + bin_dimension_font_size) * -1
      vb_width = px_bin_length + (bin_outline_width + bin_dimension_offset + bin_dimension_font_size + vb_offset_x) * 2
      vb_height = px_bin_width + (bin_outline_width + bin_dimension_offset + bin_dimension_font_size) * 2

      svg = "<svg viewbox='#{vb_x} #{vb_y} #{vb_width} #{vb_height}' style='max-height: #{vb_height}px'>"
        svg += "<text class='sheet-dimension' x='#{px_bin_length / 2}' y='-#{bin_outline_width + bin_dimension_offset}' font-size='#{bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic'>#{bin.def.length.to_l}</text>"
        svg += "<text class='sheet-dimension' x='-#{bin_outline_width + bin_dimension_offset}' y='#{px_bin_width / 2}' font-size='#{bin_dimension_font_size}' text-anchor='middle' dominant-baseline='alphabetic' transform='rotate(-90 -#{bin_outline_width + bin_dimension_offset},#{px_bin_width / 2})'>#{bin.def.width.to_l}</text>"
        svg += "<g class='sheet'>"
          svg += "<rect class='sheet-outer' x='-1' y='-1' width='#{px_bin_length + 2}' height='#{px_bin_width + 2}' />"
          svg += "<rect class='sheet-inner' x='0' y='0' width='#{px_bin_length}' height='#{px_bin_width}' />"
        svg += '</g>'
        bin.items.each do |item|

          px_item_x = _to_px(item.x)
          px_item_y = px_bin_width - _to_px(item.y)
          px_item_length = _to_px(item.def.data.def.size.length)
          px_item_width = _to_px(item.def.data.def.size.width)

          svg += "<g class='part' transform='translate(#{px_item_x} #{px_item_y}) rotate(-#{item.angle})' data-toggle='tooltip' data-html='true' title='<div>#{item.def.data.name}</div><div>x = #{item.x}</div><div>y = #{item.y}</div>'>"
            svg += "<rect class='part-projection-outer' x='0' y='-#{px_item_width}' width='#{px_item_length}' height='#{px_item_width}' />" unless bin.cuts.empty?
            svg += "<g class='part-projection'>"
              svg += "<path class='part-projection-shape' d='#{item.def.projection_def.layer_defs.map { |layer_def| "#{layer_def.poly_defs.map { |poly_def| "M #{poly_def.points.map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}" }.join(' ')}' />"
            svg += '</g>'
          svg += '</g>'

        end
        bin.cuts.sort_by { |cut| cut.depth }.each do |cut|

          px_cut_x1 = _to_px(cut.x1)
          px_cut_y1 = px_bin_width - _to_px(cut.y1)
          px_cut_x2 = _to_px(cut.x2)
          px_cut_y2 = px_bin_width - _to_px(cut.y2)

          case cut.depth
          when 0
            clazz = ' cut-trimming'
          when 1
            clazz = ' cut-bounding'
          when 2
            clazz = ' cut-internal-through'
          else
            clazz = ''
          end

          svg += "<g class='cut#{clazz}#{cut.depth < 3 ? ' cut-highlighted' : ''}' data-toggle='tooltip' title='depth = #{cut.depth}'>"
            svg += "<rect class='cut-outer' x='#{px_cut_x1 - cut_outline_width}' y='#{px_cut_y2 - cut_outline_width}' width='#{px_cut_x2 - px_cut_x1 + cut_outline_width * 2}' height='#{(px_cut_y1 - px_cut_y2 + cut_outline_width * 2).abs}' />"
            svg += "<rect class='cut-inner' x='#{px_cut_x1}' y='#{px_cut_y2}' width='#{px_cut_x2 - px_cut_x1}' height='#{(px_cut_y1 - px_cut_y2).abs}' />"
          svg += "</g>"

        end
      svg += '</svg>'

      svg
    end

  end

end
