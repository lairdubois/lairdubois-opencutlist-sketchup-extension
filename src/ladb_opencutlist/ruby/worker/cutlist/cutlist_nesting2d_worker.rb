module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../lib/fiddle/nesty/nesty'

  class CutlistNesting2dWorker

    include PartDrawingHelper
    include PixelConverterHelper

    Nesty = Fiddle::Nesty

    def initialize(cutlist,

                   group_id: ,
                   part_ids: nil,
                   std_sheet: '',
                   scrap_sheet_sizes: '',
                   spacing: '20mm',
                   trimming: '10mm',
                   rotations: 0,
                   reload_lib: false

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids
      s_length, s_width = StringUtils.split_dxd(std_sheet)
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(s_length).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(s_width).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxdxq_to_ifloats(scrap_sheet_sizes)
      @spacing = DimensionUtils.instance.str_to_ifloat(spacing).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(trimming).to_l.to_f
      @rotations = rotations.to_i
      @reload_lib = reload_lib

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

      Nesty.reload if @reload_lib

      bin_defs = []
      shape_defs = []

      bin_id = 0
      shape_id = 0

      # Add bins from scrap sheets
      @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
        ddq = scrap_sheet_size.split('x')
        length = ddq[0].strip.to_l.to_f
        width = ddq[1].strip.to_l.to_f
        count = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
        bin_defs << Nesty::BinDef.new(bin_id += 1, count, Nesty.float_to_int64(length), Nesty.float_to_int64(width), 1) # 1 = user defined
      }

      # Add bin from std sheet
      bin_defs << Nesty::BinDef.new(bin_id += 1, 1, Nesty.float_to_int64(@std_sheet_length), Nesty.float_to_int64(@std_sheet_width), 0) # 0 = Standard

      # Add shapes from parts
      fn_add_shapes = lambda { |part|

        rpaths = []

        projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part, merge_holes: true)
        projection_def.layer_defs.each do |layer_def|
          next unless layer_def.type_outer? || layer_def.type_holes?
          layer_def.poly_defs.each do |poly_def|
            rpaths << Nesty.points_to_rpath(layer_def.type_holes? ? poly_def.points.reverse : poly_def.points)
          end
        end

        shape_defs << Nesty::ShapeDef.new(shape_id += 1, part.count, rpaths, part)

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
      SKETCHUP_CONSOLE.show

      solution, message = Nesty.execute_nesting(bin_defs, shape_defs, Nesty.float_to_int64(@spacing), Nesty.float_to_int64(@trimming), @rotations)
      puts message.to_s

      svgs = []
      svgs += solution.packed_bins.map { |bin| _bin_to_svg(bin) }
      svgs += solution.unused_bins.map { |bin| _bin_to_svg(bin, '#d9534f') }

      response = {
        'unused_bins_count' => solution.unused_bins.length,
        'packed_bins_count' => solution.packed_bins.length,
        'unplaced_shapes_count' => solution.unplaced_shapes.length,
        'svgs' => svgs
      }

      response
    end

    private

    def _bin_to_svg(bin, bg_color = '#5cb85c')

      px_bin_length = _to_px(Nesty.int64_to_float(bin.def.length))
      px_bin_width = _to_px(Nesty.int64_to_float(bin.def.width))

      output = "<svg width='#{px_bin_length}' height='#{px_bin_width}' viewbox='0 -#{px_bin_width} #{px_bin_length} #{px_bin_width}'>"
      output += "<rect x='0' y='-#{px_bin_width}' width='#{px_bin_length}' height='#{px_bin_width}' fill='#{bg_color}' stroke='none' />"
      bin.shapes.each do |shape|

        px_shape_x = _to_px(Nesty.int64_to_float(shape.x))
        px_shape_y = -_to_px(Nesty.int64_to_float(shape.y))

        output += "'<g transform='translate(#{px_shape_x} #{px_shape_y})'>'"
        output += "<path d='#{shape.def.paths.map { |path| "M #{Nesty.rpath_to_points(path).map { |point| "#{_to_px(point.x).round(2)},#{-_to_px(point.y).round(2)}" }.join(' L ')} Z" }.join(' ')}' fill='rgba(0, 0, 0, 0.5)' stroke='none' />"
        output += '</g>'

      end
      output += '</svg>'

      output
    end

  end

end
