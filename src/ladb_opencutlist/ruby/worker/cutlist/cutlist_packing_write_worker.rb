module Ladb::OpenCutList

  require_relative 'cutlist_packing_worker'
  require_relative '../../constants'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../utils/color_utils'

  class CutlistPackingWriteWorker < CutlistPackingService

    include SanitizerHelper
    include DxfWriterHelper
    include SvgWriterHelper

    LAYER_BIN = 'OCL_BIN'.freeze
    LAYER_PART = 'OCL_PART'.freeze
    LAYER_LEFTOVER = 'OCL_LEFTOVER'.freeze
    LAYER_CUT = 'OCL_CUT'.freeze
    LAYER_TEXT = 'OCL_TEXT'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SVG, FILE_FORMAT_DXF ]

    def initialize(cutlist, packing,

                   file_format: FILE_FORMAT_SVG,
                   dxf_structure: DXF_STRUCTURE_LAYER,
                   unit: Length::Millimeter,
                   smoothing: false,
                   merge_holes: false,
                   include_paths: false,
                   bin_hidden: false,
                   bin_stroke_color: '#0068FF',
                   bin_fill_color: nil,
                   parts_hidden: false,
                   parts_stroke_color: nil,
                   parts_fill_color: '#000000',
                   parts_holes_stroke_color: '#000000',
                   parts_holes_fill_color: '#ffffff',
                   parts_paths_stroke_color: '#0068FF',
                   parts_paths_fill_color: nil,
                   texts_hidden: false,
                   texts_color: '#00ffff',
                   leftovers_hidden: true,
                   leftovers_stroke_color: '#aaaaaa',
                   leftovers_fill_color: nil,
                   cuts_hidden: true,
                   cuts_color: '#ff00ff',

                   hidden_bin_indices: [],
                   part_drawing_type: PART_DRAWING_TYPE_NONE


    )

      @cutlist = cutlist
      @packing = packing

      @file_format = file_format
      @dxf_structure = dxf_structure.to_i
      @unit = unit
      @smoothing = smoothing
      @merge_holes = merge_holes
      @include_paths = include_paths
      @bin_hidden = bin_hidden
      @bin_stroke_color = ColorUtils.color_create(bin_stroke_color)
      @bin_fill_color = ColorUtils.color_create(bin_fill_color)
      @parts_hidden = parts_hidden
      @parts_stroke_color = ColorUtils.color_create(parts_stroke_color)
      @parts_fill_color = ColorUtils.color_create(parts_fill_color)
      @parts_holes_stroke_color = ColorUtils.color_create(parts_holes_stroke_color)
      @parts_holes_fill_color = ColorUtils.color_create(parts_holes_fill_color)
      @parts_paths_stroke_color = ColorUtils.color_create(parts_paths_stroke_color)
      @parts_paths_fill_color = ColorUtils.color_create(parts_paths_fill_color)
      @texts_hidden = texts_hidden
      @texts_color = ColorUtils.color_create(texts_color)
      @leftovers_hidden = leftovers_hidden
      @leftovers_stroke_color = ColorUtils.color_create(leftovers_stroke_color)
      @leftovers_fill_color = ColorUtils.color_create(leftovers_fill_color)
      @cuts_hidden = cuts_hidden
      @cuts_color = ColorUtils.color_create(cuts_color)

      @hidden_bin_indices = hidden_bin_indices
      @part_drawing_type = part_drawing_type.to_i

      @_projection_defs = {}

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @packing && @packing.def.group
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)

      # Ask for output dir
      dir = UI.select_directory(title: PLUGIN.get_i18n_string('tab.cutlist.packing.write.title'), directory: '')
      if dir

        packing_def = @packing.def
        group = packing_def.group
        folder_name = _sanitize_filename("#{group.material_display_name} - #{group.std_dimension}")
        folder_path = File.join(dir, folder_name)

        begin

          if File.exist?(folder_path)
            if UI.messagebox(PLUGIN.get_i18n_string('core.messagebox.dir_override', { :target => folder_name, :parent => File.basename(dir) }), MB_YESNO) == IDYES
              FileUtils.remove_dir(folder_path, true)
            else
              return { :cancelled => true }
            end
          end
          Dir.mkdir(folder_path)

          bin_index = 1
          packing_def.solution_def.bin_defs.each do |bin_def|
            _write_to_path(folder_path, bin_def, bin_index) unless @hidden_bin_indices.include?(bin_index)
            bin_index += bin_def.count
          end

          return { :export_path => folder_path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'core.error.failed_export_to', { :path => folder_path, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_to_path(export_path, bin_def, bin_index)

      # Open output file
      file = File.new(File.join(export_path, "bin_#{bin_index.to_s.rjust(3, '0')}#{bin_def.count > 1 ? "_to_#{(bin_index + bin_def.count - 1).to_s.rjust(3, '0')}" : ''}.#{@file_format}") , 'w')

      case @file_format
      when FILE_FORMAT_SVG
        _write_to_svg_file(file, bin_def)
      when FILE_FORMAT_DXF
        _write_to_dxf_file(file, bin_def)
      end

      # Close output file
      file.close

    end

    def _write_to_svg_file(file, bin_def)

      packing_def = @packing.def
      options_def = packing_def.solution_def.options_def
      is_1d = options_def.problem_type == Packy::PROBLEM_TYPE_ONEDIMENSIONAL

      unit_sign, unit_factor = _svg_get_unit_sign_and_factor(@unit)
      unit_transformation = Geom::Transformation.scaling(unit_factor, unit_factor, 1.0)

      bin_type_def = bin_def.bin_type_def

      bin_length = bin_type_def.length
      bin_width = bin_type_def.width

      size = Geom::Point3d.new(
        bin_type_def.length,
        bin_type_def.width
      ).transform(unit_transformation)

      width = _svg_value(size.x)
      height = _svg_value(size.y)

      _svg_write_start(file, 0, 0, width, height, unit_sign)

      unless @bin_hidden

        _svg_write_group_start(file, id: LAYER_BIN)
          _svg_write_tag(file, 'rect', {
            x: 0,
            y: 0,
            width: width,
            height: height,
            stroke: _svg_stroke_color_hex(@bin_stroke_color, @bin_fill_color),
            fill: _svg_fill_color_hex(@bin_fill_color),
          })
        _svg_write_group_end(file)

      end

      unless @parts_hidden
        _svg_write_group_start(file, id: LAYER_PART)
        bin_def.item_defs.each do |item_def|

          item_type_def = item_def.item_type_def
          projection_def = item_type_def.projection_def
          part = item_type_def.part
          part_def = part.def
          text = _evaluate_item_text(options_def.items_formula, part, item_def.instance_info)

          id = _svg_sanitize_identifier("#{LAYER_PART}_#{part.number.to_s.rjust(3, '_')}")

          item_length = item_type_def.length
          item_width = is_1d ? bin_width : item_type_def.width
          item_x = item_def.x
          item_y = item_def.y

          part_length = part_def.size.length
          part_width = part_def.size.width

          t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, item_def.angle.degrees)
          t *= Geom::Transformation.scaling(-1.0, 1.0, 1.0) if item_def.mirror
          pts = [
            Geom::Point3d.new(0, 0),
            Geom::Point3d.new(item_length, 0),
            Geom::Point3d.new(item_length, item_width),
            Geom::Point3d.new(0, item_width),
          ]
          pts.each { |pt| pt.transform!(t) }
          bounds = Geom::BoundingBox.new.add(pts)

          item_rect_width = bounds.width.to_f
          item_rect_height = bounds.height.to_f
          item_rect_x = _compute_x_with_origin_corner(options_def.problem_type, options_def.origin_corner, item_x + bounds.min.x.to_f, item_rect_width, bin_length)
          item_rect_y = _compute_y_with_origin_corner(options_def.problem_type, options_def.origin_corner, item_y + bounds.min.y.to_f, item_rect_height, bin_width)

          position = Geom::Point3d.new(
            item_rect_x,
            bin_width - item_rect_y - item_rect_height
          ).transform(unit_transformation)
          size = Geom::Point3d.new(
            item_rect_width,
            item_rect_height
          ).transform(unit_transformation)

          if projection_def.is_a?(DrawingProjectionDef)

            transformation = unit_transformation
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(item_rect_x, item_rect_y - bin_width))
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(item_rect_width / 2, item_rect_height / 2))
            transformation *= Geom::Transformation.rotation(ORIGIN, Z_AXIS, item_def.angle.degrees) if item_def.angle != 0
            transformation *= Geom::Transformation.scaling(-1.0, 1.0, 1.0) if item_def.mirror
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(-part_length / 2, -part_width / 2))

            _svg_write_group_start(file, {
              id: id,
              'serif:id': id,
              'inkscape:label': id
            })

              _svg_write_projection_def(file, projection_def,
                                        smoothing: @smoothing,
                                        transformation: transformation,
                                        unit_transformation: unit_transformation,
                                        unit_sign: unit_sign,
                                        stroke_color: @parts_stroke_color,
                                        fill_color: @parts_fill_color,
                                        holes_stroke_color: @parts_holes_stroke_color,
                                        holes_fill_color: @parts_holes_fill_color,
                                        paths_stroke_color: @parts_paths_stroke_color,
                                        paths_fill_color: @parts_paths_fill_color,
                                        prefix: LAYER_PART)
              _svg_write_label(file, position.x, position.y, size.x, size.y, text, (item_def.angle % 180) != 0, _svg_stroke_color_hex(@texts_color)) unless @texts_hidden

            _svg_write_group_end(file)

          else

            _svg_write_tag(file, 'rect', {
              x: _svg_value(position.x),
              y: _svg_value(position.y),
              width: _svg_value(size.x),
              height: _svg_value(size.y),
              stroke: _svg_stroke_color_hex(@parts_stroke_color, @parts_fill_color),
              fill: _svg_fill_color_hex(@parts_fill_color),
              id: id,
              'serif:id': id,
              'inkscape:label': id
            })
            _svg_write_label(file, position.x, position.y, size.x, size.y, text, (item_def.angle % 180) != 0, _svg_stroke_color_hex(@texts_color)) unless @texts_hidden

          end

        end
        _svg_write_group_end(file)
      end

      unless @leftovers_hidden
        _svg_write_group_start(file, id: LAYER_LEFTOVER)
          bin_def.leftover_defs.each do |leftover_def|

            leftover_rect_width = leftover_def.length
            leftover_rect_height = is_1d ? bin_width : leftover_def.width
            leftover_rect_x = _compute_x_with_origin_corner(options_def.problem_type, options_def.origin_corner, leftover_def.x, leftover_rect_width, bin_length)
            leftover_rect_y = _compute_y_with_origin_corner(options_def.problem_type, options_def.origin_corner, leftover_def.y, leftover_rect_height, bin_width)

            position = Geom::Point3d.new(
              leftover_rect_x,
              bin_width - leftover_rect_y - leftover_rect_height
            ).transform(unit_transformation)
            size = Geom::Point3d.new(
              leftover_rect_width,
              leftover_rect_height
            ).transform(unit_transformation)

            _svg_write_tag(file, 'rect', {
              x: _svg_value(position.x),
              y: _svg_value(position.y),
              width: _svg_value(size.x),
              height: _svg_value(size.y),
              stroke: _svg_stroke_color_hex(@leftovers_stroke_color, @leftovers_fill_color),
              fill: _svg_fill_color_hex(@leftovers_fill_color),
            })

          end
        _svg_write_group_end(file)
      end

      unless @cuts_hidden
        _svg_write_group_start(file, id: LAYER_CUT)
          bin_def.cut_defs.each do |cut_def|

            if cut_def.horizontal?
              cut_rect_width = cut_def.length
              cut_rect_height = options_def.spacing
            else
              cut_rect_width = options_def.spacing
              cut_rect_height = cut_def.length
            end
            cut_rect_x = _compute_x_with_origin_corner(options_def.problem_type, options_def.origin_corner, cut_def.x, cut_rect_width, bin_length)
            cut_rect_y = _compute_y_with_origin_corner(options_def.problem_type, options_def.origin_corner, cut_def.y, cut_rect_height, bin_width)

            case options_def.origin_corner
            when ORIGIN_CORNER_TOP_LEFT
              cut_rect_y += cut_rect_height if cut_def.horizontal?
            when ORIGIN_CORNER_TOP_RIGHT
              cut_rect_x += cut_rect_width if cut_def.vertical?
              cut_rect_y += cut_rect_height if cut_def.horizontal?
            when ORIGIN_CORNER_BOTTOM_RIGHT
              cut_rect_x += cut_rect_width if cut_def.vertical?
            end

            position1 = Geom::Point3d.new(
              cut_rect_x,
              bin_width - cut_rect_y
            ).transform(unit_transformation)
            position2 = Geom::Point3d.new(
              cut_rect_x + (cut_def.horizontal? ? cut_def.length : 0),
              bin_width - cut_rect_y - (cut_def.vertical? ? cut_def.length : 0)
            ).transform(unit_transformation)

            _svg_write_tag(file, 'line', {
              x1: _svg_value(position1.x),
              y1: _svg_value(position1.y),
              x2: _svg_value(position2.x),
              y2: _svg_value(position2.y),
              stroke: _svg_stroke_color_hex(@cuts_color),
            })

          end
        _svg_write_group_end(file)
      end

      _svg_write_end(file)

    end

    def _write_to_dxf_file(file, bin_def)
      # TODO
    end

  end

end