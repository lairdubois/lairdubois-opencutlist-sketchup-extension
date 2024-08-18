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

    ENGINE_RECTANGLE = 'rectangle'
    ENGINE_RECTANGLEGUILLOTINE = 'rectangleguillotine'
    ENGINE_IRREGULAR = 'irregular'
    ENGINE_ONEDIMENSIONAL = 'onedimensional'

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

                   group_id: ,
                   part_ids: nil,
                   std_sheet: '',
                   scrap_sheet_sizes: '',

                   engine: ENGINE_RECTANGLE,
                   objective: 'bin-packing',
                   spacing: '20mm',
                   trimming: '10mm',
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

      @engine = engine
      @objective = objective
      @spacing = DimensionUtils.instance.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(trimming).to_l.to_f
      @verbosity_level = verbosity_level.to_i

      @rectangleguillotine_cut_type = rectangleguillotine_cut_type
      @rectangleguillotine_first_stage_orientation = rectangleguillotine_first_stage_orientation

      @irregular_rotations = [ 0, [ irregular_rotations.to_i, AVAILABLE_ROTATIONS.length - 1 ].min].max

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      model = Sketchup.active_model
      return{ :errors => [ 'default.error' ] } unless model

      group = @cutlist.get_group(@group_id)
      return { :errors => [ 'default.error' ] } unless group

      parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids)
      return { :errors => [ 'default.error' ] } if parts.empty?

      SKETCHUP_CONSOLE.clear

      bin_defs = []
      item_defs = []

      bin_id = 0
      item_id = 0

      input = {
        problem_type: @engine,
        parameters: {
          "optimization_mode": "not-anytime",
          "verbosity_level": @verbosity_level,
          "not_anytime_tree_search_queue_size": 512
        },
        instance: {
          objective: @objective,
          parameters: {
            cut_type: @rectangleguillotine_cut_type,
            cut_thickness: _to_packy(@spacing),
            first_stage_orientation: @rectangleguillotine_first_stage_orientation
          },
          bin_types: [],
          item_types: [],
        }
      }

      # Add bins from scrap sheets
      @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
        ddq = scrap_sheet_size.split('x')
        length = ddq[0].strip.to_l.to_f
        width = ddq[1].strip.to_l.to_f
        count = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
        bin_defs << Packy::BinDef.new(bin_id += 1, count, _to_packy(length), _to_packy(width), 1) # 1 = user defined

        input[:instance][:bin_types] << {
          copies: count,
          type: 'rectangle',
          length: _to_packy(length),
          width: _to_packy(width)
        }

      }

      parts_count = parts.map(&:count).inject(0, :+)  # .map(&:count).inject(0, :+) == .sum { |portion| part.count } compatible with ruby < 2.4

      # Add bin from std sheet
      if @std_sheet_width > 0 && @std_sheet_length > 0
        bin_defs << Packy::BinDef.new(bin_id += 1, parts_count, _to_packy(@std_sheet_length), _to_packy(@std_sheet_width), 0) # 0 = Standard

        input[:instance][:bin_types] << {
          copies: parts_count,
          type: 'rectangle',
          length: _to_packy(@std_sheet_length),
          width: _to_packy(@std_sheet_width)
        }

      end

      # Add items from parts
      fn_add_items = lambda { |part|

        if @engine == ENGINE_IRREGULAR

          projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part, compute_shell: true)

          item_defs << Packy::ItemDef.new(
            item_id += 1,
            part.count,
            @irregular_rotations,
            projection_def.layer_defs.map { |layer_def|
              next unless layer_def.type_outer? || layer_def.type_holes?
              layer_def.poly_defs.map { |poly_def| Packy.points_to_rpath(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points).map { |v| _to_packy(v) } }
            }.flatten(1).compact,
            part
          )

          input[:instance][:item_types] << {
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

          input[:instance][:item_types] << {
            copies: part.count,
            length: _to_packy(part.def.size.length),
            width: _to_packy(part.def.size.width),
            oriented: (group.material_grained  && !part.ignore_grain_direction) ? false : true
          }

        end

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

      puts "-- input --"
      puts input.to_json
      puts "-- input --"

      output = Packy.optimize(input)

      puts " "
      puts "-- output --"
      puts output
      puts "-- output --"


      # case @engine
      # when ENGINE_RECTANGLE
      #   solution, message = Packy.execute_rectangle(bin_defs, item_defs, @objective, _to_packy(@spacing), _to_packy(@trimming), @verbosity_level)
      # when ENGINE_RECTANGLEGUILLOTINE
      #   solution, message = Packy.execute_rectangleguillotine(bin_defs, item_defs, @objective, @rectangleguillotine_cut_type, @rectangleguillotine_first_stage_orientation, _to_packy(@spacing), _to_packy(@trimming), @verbosity_level)
      # when ENGINE_IRREGULAR
      #   solution, message = Packy.execute_irregular(bin_defs, item_defs, @objective, _to_packy(@spacing), _to_packy(@trimming), @verbosity_level)
      # when ENGINE_ONEDIMENSIONAL
      #   solution, message = Packy.execute_onedimensional(bin_defs, item_defs, @objective, _to_packy(@spacing), _to_packy(@trimming), @verbosity_level)
      # else
      #   return { :errors => [ "Unknow engine : #{@engine}" ] }
      # end
      # # puts message.to_s
      #
      # {
      #   'unused_bins_count' => solution.unused_bins.length,
      #   'packed_bins_count' => solution.packed_bins.length,
      #   'unplaced_items_count' => solution.unplaced_items.length,
      #   'packed_bins' => solution.packed_bins.map { |bin| {
      #     length: bin.def.length.to_l.to_s,
      #     width: bin.def.width.to_l.to_s,
      #     type: bin.def.type,
      #     svg: _bin_to_svg(bin)
      #   } },
      #   'unused_bins' => solution.unused_bins.map { |bin| {
      #     length: bin.def.length.to_l.to_s,
      #     width: bin.def.width.to_l.to_s,
      #     type: bin.def.type,
      #     svg: _bin_to_svg(bin, '#d9534f')
      #   } }
      # }
      {}
    end

    private

    def _to_packy(l)
      if @engine == ENGINE_IRREGULAR
        return l.to_f.round(6)
      end
      (l.to_l.to_mm * 100.0).to_i
    end

    def _from_packy(l)
      if @engine == ENGINE_IRREGULAR
        return l.to_f
      end
      l.mm / 100.0
    end

    def _bin_to_svg(bin, bg_color = '#dddddd')

      px_bin_length = _to_px(_from_packy(bin.def.length))
      px_bin_width = _to_px(_from_packy(bin.def.width))

      svg = "<svg width='#{px_bin_length}' height='#{px_bin_width}' viewbox='0 -#{px_bin_width} #{px_bin_length} #{px_bin_width}'>"
      svg += "<rect x='0' y='-#{px_bin_width}' width='#{px_bin_length}' height='#{px_bin_width}' fill='#{bg_color}' stroke='none' />"
      bin.items.each do |item|

        l_item_x = _from_packy(item.x).to_l
        l_item_y = _from_packy(item.y).to_l

        px_item_x = _to_px(l_item_x)
        px_item_y = -_to_px(l_item_y)

        svg += "<g class='ladb-packy-part' transform='translate(#{px_item_x} #{px_item_y}) rotate(-#{item.angle.radians})'>"
        svg += "<path d='#{item.def.paths.map { |path| "M #{Packy.rpath_to_points(path).map { |point| "#{_to_px(_from_packy(point.x)).round(2)},#{-_to_px(_from_packy(point.y)).round(2)}" }.join(' L ')} Z" }.join(' ')}' data-toggle='tooltip' data-html='true' title='<div>#{item.def.data.name}</div><div>x = #{l_item_x}</div><div>y = #{l_item_y}</div>' />"
        svg += '</g>'

      end
      bin.cuts.sort_by { |cut| cut.depth }.each do |cut|

        next if cut.depth < 0

        l_cut_x1 = _from_packy(cut.x1).to_l
        l_cut_y1 = _from_packy(cut.y1).to_l
        l_cut_x2 = _from_packy(cut.x2).to_l
        l_cut_y2 = _from_packy(cut.y2).to_l

        px_cut_x1 = _to_px(l_cut_x1)
        px_cut_y1 = -_to_px(l_cut_y1)
        px_cut_x2 = _to_px(l_cut_x2)
        px_cut_y2 = -_to_px(l_cut_y2)

        case cut.depth
        when 0
          color = ColorUtils.color_to_hex(Sketchup::Color.new('red').blend(Sketchup::Color.new('blue'), 1.0))
        when 1
          color = ColorUtils.color_to_hex(Sketchup::Color.new('red').blend(Sketchup::Color.new('blue'), 0.8))
        when 2
          color = ColorUtils.color_to_hex(Sketchup::Color.new('red').blend(Sketchup::Color.new('blue'), 0.6))
        when 3
          color = ColorUtils.color_to_hex(Sketchup::Color.new('red').blend(Sketchup::Color.new('blue'), 0.4))
        when 4
          color = ColorUtils.color_to_hex(Sketchup::Color.new('red').blend(Sketchup::Color.new('blue'), 0.2))
        else
          color = '#0000ff'
        end

        svg += "<rect class='ladb-packy-cut' x='#{px_cut_x1}' y='#{px_cut_y2}' width='#{px_cut_x2 - px_cut_x1}' height='#{(px_cut_y1 - px_cut_y2).abs}' stroke='none' fill='#{color}' data-toggle='tooltip' title='depth = #{cut.depth}' />"

      end
      svg += '</svg>'

      svg
    end

  end

end
