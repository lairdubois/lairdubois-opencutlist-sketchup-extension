module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/color_utils'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../worker/common/common_drawing_projection_worker'

  class CommonWriteDrawing2dWorker

    include DxfWriterHelper
    include SvgWriterHelper
    include SanitizerHelper

    LAYER_PART = 'OCL_PART'.freeze
    LAYER_EDGE = 'OCL_EDGE'.freeze
    LAYER_ANCHOR = 'OCL_ANCHOR'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SVG, FILE_FORMAT_DXF ]

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @folder_path = settings.fetch('folder_path', nil)
      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)
      @anchor = settings.fetch('anchor', false)
      @smoothing = settings.fetch('smoothing', false)
      @merge_holes = settings.fetch('merge_holes', false)
      @parts_stroke_color = ColorUtils.color_create(settings.fetch('parts_stroke_color', nil))
      @parts_fill_color = ColorUtils.color_create(settings.fetch('parts_fill_color', nil))
      @parts_holes_stroke_color = ColorUtils.color_create(settings.fetch('parts_holes_stroke_color', nil))
      @parts_holes_fill_color = ColorUtils.color_create(settings.fetch('parts_holes_fill_color', nil))
      @parts_paths_stroke_color = ColorUtils.color_create(settings.fetch('parts_paths_stroke_color', nil))

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel if needed
      if @folder_path.nil? || !File.exist?(@folder_path)
        path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => @file_format.upcase }), '', "#{@file_name}.#{@file_format}")
      else
        path = File.join(@folder_path, "#{@file_name}.#{@file_format}")
      end
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          # Compute projection
          projection_def = CommonDrawingProjectionWorker.new(@drawing_def, {
            'origin_position' => @anchor ? CommonDrawingProjectionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingProjectionWorker::ORIGIN_POSITION_BOUNDS_MIN,
            'merge_holes' => @merge_holes
          }).run
          if projection_def.is_a?(DrawingProjectionDef)

            # Open output file
            file = File.new(path , 'w')

            case @file_format
            when FILE_FORMAT_SVG
              _write_to_svg_file(file, projection_def)
            when FILE_FORMAT_DXF
              _write_to_dxf_file(file, projection_def)
            end

            # Close output file
            file.close

          end

          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'core.error.failed_export_to', { :path => path, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_to_svg_file(file, projection_def)

      if @anchor
        # Recompute bounding box to be sure to extends to anchor triangle
        bounds = Geom::BoundingBox.new
        bounds.add(projection_def.bounds.min)
        bounds.add(projection_def.bounds.max)
        bounds.add([ Geom::Point3d.new, Geom::Point3d.new(0, 10.mm), Geom::Point3d.new(5.mm, 0) ])
      else
        bounds = projection_def.bounds
      end

      unit_sign, unit_factor = _svg_get_unit_sign_and_factor(@unit)
      unit_transformation = Geom::Transformation.scaling(unit_factor, unit_factor, 1.0)

      origin = Geom::Point3d.new(
        bounds.min.x,
        -(bounds.height + bounds.min.y)
      ).transform(unit_transformation)
      size = Geom::Point3d.new(
        bounds.width,
        bounds.height
      ).transform(unit_transformation)

      x = _svg_value(origin.x)
      y = _svg_value(origin.y)
      width = _svg_value(size.x)
      height = _svg_value(size.y)

      _svg_write_start(file, x, y, width, height, unit_sign)

      unless projection_def.layer_defs.empty?

        _svg_write_group_start(file, id: LAYER_PART)
        _svg_write_projection_def(file, projection_def, @smoothing, unit_transformation, unit_transformation, unit_sign, @parts_stroke_color, @parts_fill_color, @parts_holes_stroke_color, @parts_holes_fill_color, @parts_paths_stroke_color, LAYER_PART)
        _svg_write_group_end(file)

      end

      if @anchor

        size = Geom::Point3d.new(
          5.mm,
          10.mm
        ).transform(unit_transformation)

        x1 = 0
        y1 = 0
        x2 = 0
        y2 = -size.y.to_f
        x3 = size.x.to_f
        y3 = 0

        _svg_write_group_start(file, id: LAYER_ANCHOR)
        _svg_write_tag(file, 'polygon', {
          points: "#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}",
          fill: '#FF0000'
        })
        _svg_write_group_end(file)

      end

      _svg_write_end(file)

    end

    def _write_to_dxf_file(file, projection_def)

      unit_factor = _dxf_get_unit_factor(@unit)
      unit_transformation = Geom::Transformation.scaling(ORIGIN, unit_factor, unit_factor, 1.0)

      min = projection_def.bounds.min.transform(unit_transformation)
      max = projection_def.bounds.max.transform(unit_transformation)

      layer_defs = []
      layer_defs.concat(_dxf_get_projection_def_depth_layer_defs(projection_def, @parts_stroke_color, @parts_holes_stroke_color, @parts_paths_stroke_color, unit_factor, LAYER_PART).uniq { |layer_def| layer_def.name })

      _dxf_write_start(file)
      _dxf_write_section_header(file, @unit, min, max)
      _dxf_write_section_classes(file)
      _dxf_write_section_tables(file, min, max, layer_defs)
      _dxf_write_section_blocks(file)
      _dxf_write_section_entities(file) do

        _dxf_write_projection_def_geometry(file, projection_def, @smoothing, unit_transformation, unit_transformation, LAYER_PART)

      end
      _dxf_write_section_objects(file)
      _dxf_write_end(file)

    end

  end

end