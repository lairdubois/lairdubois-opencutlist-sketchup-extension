module Ladb::OpenCutList

  require 'json'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/packy/packy'

  class CutlistNesting2dWorker

    include PartDrawingHelper
    include PixelConverterHelper

    Packy = Fiddle::Packy

    ENGINE_RECTANGLE = 'rectangle'
    ENGINE_RECTANGLEGUILLOTINE = 'rectangleguillotine'
    ENGINE_IRREGULAR = 'irregular'
    ENGINE_ONEDIMENSIONAL = 'onedimensional'

    def initialize(cutlist,

                   group_id: ,
                   part_ids: nil,
                   std_sheet: '',
                   scrap_sheet_sizes: '',

                   engine: ENGINE_RECTANGLE,
                   objective: 'bin-packing',
                   cut_type: 'exact',
                   first_stage_orientation: 'horizontal',
                   spacing: '20mm',
                   trimming: '10mm',
                   verbosity_level: 1

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
      @cut_type = cut_type
      @first_stage_orientation = first_stage_orientation
      @spacing = DimensionUtils.instance.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(trimming).to_l.to_f
      @verbosity_level = verbosity_level.to_i

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

      bin_defs = []
      shape_defs = []

      bin_id = 0
      shape_id = 0

      json = {
        objective: @objective,
        bin_types: [],
        item_types: [],
      }

      # Add bins from scrap sheets
      @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
        ddq = scrap_sheet_size.split('x')
        length = ddq[0].strip.to_l.to_f
        width = ddq[1].strip.to_l.to_f
        count = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
        bin_defs << Packy::BinDef.new(bin_id += 1, count, Packy.float_to_int64(length), Packy.float_to_int64(width), 1) # 1 = user defined

        json[:bin_types] << {
          copies: count,
          type: 'rectangle',
          width: length.to_mm.round(3),
          height: width.to_mm.round(3)
        }

      }

      parts_count = parts.sum { |part| part.count }

      # Add bin from std sheet
      if @std_sheet_width > 0 && @std_sheet_length > 0
        bin_defs << Packy::BinDef.new(bin_id += 1, parts_count, Packy.float_to_int64(@std_sheet_length), Packy.float_to_int64(@std_sheet_width), 0) # 0 = Standard

        json[:bin_types] << {
          copies: parts_count,
          type: 'rectangle',
          width: @std_sheet_length.to_mm.round(3),
          height: @std_sheet_width.to_mm.round(3)
        }

      end

      # Add shapes from parts
      fn_add_shapes = lambda { |part|

        rpaths = []
        vertices = []
        holes = []

        projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part, merge_holes: true)
        projection_def.layer_defs.each do |layer_def|
          next unless layer_def.type_outer? || layer_def.type_holes?
          layer_def.poly_defs.each do |poly_def|
            rpaths << Packy.points_to_rpath(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points)

            if layer_def.type_holes?
              holes << {
                type: 'polygon',
                vertices: poly_def.points.map { |point| { x: point.x.to_mm.round(3), y: point.y.to_mm.round(3) } }
              }
            else
              vertices = poly_def.points.map { |point| { x: point.x.to_mm.round(3), y: point.y.to_mm.round(3) } }
            end

          end
        end

        shape_defs << Packy::ShapeDef.new(shape_id += 1, part.count, (group.material_grained  && !part.ignore_grain_direction) ? 0 : 1, rpaths, part)

        json[:item_types] << {
          copies: part.count,
          type: 'polygon',
          vertices: vertices,
          holes: holes
        }


      }
      parts.each { |part|
        if part.instance_of?(FolderPart)
          part.children.each { |child_part|
            fn_add_shapes.call(child_part)
          }
        else
          fn_add_shapes.call(part)
        end
      }

      SKETCHUP_CONSOLE.clear

      puts json.to_json

      case @engine
      when ENGINE_RECTANGLE
        solution, message = Packy.execute_rectangle(bin_defs, shape_defs, @objective, Packy.float_to_int64(@spacing), Packy.float_to_int64(@trimming), @verbosity_level)
      when ENGINE_RECTANGLEGUILLOTINE
        solution, message = Packy.execute_rectangleguillotine(bin_defs, shape_defs, @objective, @cut_type, @first_stage_orientation, Packy.float_to_int64(@spacing), Packy.float_to_int64(@trimming), @verbosity_level)
      when ENGINE_IRREGULAR
        solution, message = Packy.execute_irregular(bin_defs, shape_defs, @objective, Packy.float_to_int64(@spacing), Packy.float_to_int64(@trimming), @verbosity_level)
      when ENGINE_ONEDIMENSIONAL
        solution, message = Packy.execute_onedimensional(bin_defs, shape_defs, @objective, Packy.float_to_int64(@spacing), Packy.float_to_int64(@trimming), @verbosity_level)
      else
        return { :errors => [ "Unknow engine : #{@engine}" ] }
      end
      puts message.to_s

      {
        'unused_bins_count' => solution.unused_bins.length,
        'packed_bins_count' => solution.packed_bins.length,
        'unplaced_shapes_count' => solution.unplaced_shapes.length,
        'packed_bins' => solution.packed_bins.map { |bin| {
          length: Packy.int64_to_float(bin.def.length).to_l.to_s,
          width: Packy.int64_to_float(bin.def.width).to_l.to_s,
          type: bin.def.type,
          svg: _bin_to_svg(bin)
        } },
        'unused_bins' => solution.unused_bins.map { |bin| {
          length: Packy.int64_to_float(bin.def.length).to_l.to_s,
          width: Packy.int64_to_float(bin.def.width).to_l.to_s,
          type: bin.def.type,
          svg: _bin_to_svg(bin, '#d9534f')
        } }
      }
    end

    private

    def _bin_to_svg(bin, bg_color = '#dddddd')

      px_bin_length = _to_px(Packy.int64_to_float(bin.def.length))
      px_bin_width = _to_px(Packy.int64_to_float(bin.def.width))

      svg = "<svg width='#{px_bin_length}' height='#{px_bin_width}' viewbox='0 -#{px_bin_width} #{px_bin_length} #{px_bin_width}'>"
      svg += "<rect x='0' y='-#{px_bin_width}' width='#{px_bin_length}' height='#{px_bin_width}' fill='#{bg_color}' stroke='none' />"
      bin.shapes.each do |shape|

        l_shape_x = Packy.int64_to_float(shape.x).to_l
        l_shape_y = Packy.int64_to_float(shape.y).to_l

        px_shape_x = _to_px(l_shape_x)
        px_shape_y = -_to_px(l_shape_y)

        svg += "<g class='ladb-packy-part' transform='translate(#{px_shape_x} #{px_shape_y}) rotate(-#{shape.angle})'>"
        svg += "<path d='#{shape.def.paths.map { |path| "M #{Packy.rpath_to_points(path).map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}' data-toggle='tooltip' data-html='true' title='<div>#{shape.def.data.name}</div><div>x = #{l_shape_x}</div><div>y = #{l_shape_y}</div>' />"
        svg += '</g>'

      end
      bin.cuts.sort_by { |cut| cut.depth }.each do |cut|

        next if cut.depth < 0

        l_cut_x1 = Packy.int64_to_float(cut.x1).to_l
        l_cut_y1 = Packy.int64_to_float(cut.y1).to_l
        l_cut_x2 = Packy.int64_to_float(cut.x2).to_l
        l_cut_y2 = Packy.int64_to_float(cut.y2).to_l

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
