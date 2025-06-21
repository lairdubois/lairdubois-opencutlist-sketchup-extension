module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/color_utils'

  class CutlistCuttingdiagram1dWriteWorker

    include SanitizerHelper
    include DxfWriterHelper
    include SvgWriterHelper
    include PartDrawingHelper
    include PixelConverterHelper

    LAYER_BAR = 'OCL_BAR'.freeze
    LAYER_PART = 'OCL_PART'.freeze
    LAYER_LEFTOVER = 'OCL_LEFTOVER'.freeze
    LAYER_CUT = 'OCL_CUT'.freeze
    LAYER_TEXT = 'OCL_TEXT'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SVG, FILE_FORMAT_DXF ]

    def initialize(cutlist, cuttingdiagram1d,

                   file_format: FILE_FORMAT_SVG,
                   dxf_structure: DXF_STRUCTURE_LAYER,
                   unit: Length::Millimeter,
                   smoothing: false,
                   merge_holes: false,
                   include_paths: false,
                   bar_hidden: false,
                   bar_stroke_color: '#0068FF',
                   bar_fill_color: nil,
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

                   hidden_bar_indices: [],
                   part_drawing_type: PART_DRAWING_TYPE_NONE,
                   use_names: false


    )

      @cutlist = cutlist
      @cuttingdiagram1d = cuttingdiagram1d

      @file_format = file_format
      @dxf_structure = dxf_structure.to_i
      @unit = unit
      @smoothing = smoothing
      @merge_holes = merge_holes
      @include_paths = include_paths
      @bar_hidden = bar_hidden
      @bar_stroke_color = ColorUtils.color_create(bar_stroke_color)
      @bar_fill_color = ColorUtils.color_create(bar_fill_color)
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

      @hidden_bar_indices = hidden_bar_indices
      @part_drawing_type = part_drawing_type.to_i
      @use_names = use_names

      @_projection_defs = {}

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram1d && @cuttingdiagram1d.def.group
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)

      # Ask for output dir
      dir = UI.select_directory(title: PLUGIN.get_i18n_string('tab.cutlist.cuttingdiagram.write.title'), directory: '')
      if dir

        group = @cuttingdiagram1d.def.group
        folder = _sanitize_filename("#{group.material_display_name} - #{group.std_dimension}")
        path = File.join(dir, folder)

        begin

          if File.exist?(path)
            if UI.messagebox(PLUGIN.get_i18n_string('core.messagebox.dir_override', { :target => folder, :parent => File.basename(dir) }), MB_YESNO) == IDYES
              FileUtils.remove_dir(path, true)
            else
              return { :cancelled => true }
            end
          end
          Dir.mkdir(path)

          bar_index = 1
          @cuttingdiagram1d.bars.each do |bar|
            _write_to_path(path, bar, bar_index) unless @hidden_bar_indices.include?(bar_index)
            bar_index += bar.count
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

    def _write_to_path(export_path, bar, bar_index)

      # Open output file
      file = File.new(File.join(export_path, "bar_#{bar_index.to_s.rjust(3, '0')}#{bar.count > 1 ? "_to_#{(bar_index + bar.count - 1).to_s.rjust(3, '0')}" : ''}.#{@file_format}") , 'w')

      case @file_format
      when FILE_FORMAT_SVG
        _write_to_svg_file(file, bar)
      when FILE_FORMAT_DXF
        _write_to_dxf_file(file, bar)
      end

      # Close output file
      file.close

    end

    def _write_to_svg_file(file, bar)

      unit_sign, unit_factor = _svg_get_unit_sign_and_factor(@unit)
      unit_transformation = Geom::Transformation.scaling(unit_factor, unit_factor, 1.0)

      size = Geom::Point3d.new(
        _to_inch(bar.px_length),
        _to_inch(bar.px_width)
      ).transform(unit_transformation)

      width = _svg_value(size.x)
      height = _svg_value(size.y)

      _svg_write_start(file, 0, 0, width, height, unit_sign)

      unless @bar_hidden

        _svg_write_group_start(file, id: LAYER_BAR)
        _svg_write_tag(file, 'rect', {
          x: 0,
          y: 0,
          width: width,
          height: height,
          stroke: _svg_stroke_color_hex(@bar_stroke_color, @bar_fill_color),
          fill: _svg_fill_color_hex(@bar_fill_color),
        })
        _svg_write_group_end(file)

      end

      unless @parts_hidden
        _svg_write_group_start(file, id: LAYER_PART)
        bar.parts.each do |part|

          id = _svg_sanitize_identifier("#{LAYER_PART}_#{part.number.to_s.rjust(3, '_')}#{@use_names ? "_#{part.name}" : ''}")

          position = Geom::Point3d.new(
            _to_inch(part.px_x),
            0
          ).transform(unit_transformation)
          size = Geom::Point3d.new(
            _to_inch(part.px_length),
            _to_inch(bar.px_width)
          ).transform(unit_transformation)

          projection_def = _get_part_projection_def(part)
          if projection_def.is_a?(DrawingProjectionDef)

            part_x = _to_inch(part.px_x)
            part_y = _to_inch(-bar.px_width)
            part_x_offset = _to_inch(part.px_x_offset)

            transformation = unit_transformation
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(part_x + part_x_offset, part_y))

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
            _svg_write_label(file, position.x, position.y, size.x, size.y, @use_names ? part.name : part.number, size.x, size.y, 0, 0,0, _svg_stroke_color_hex(@texts_color)) unless @texts_hidden

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
            _svg_write_label(file, position.x, position.y, size.x, size.y, @use_names ? part.name : part.number, size.x, size.y, 0, 0,0, _svg_stroke_color_hex(@texts_color)) unless @texts_hidden

          end

        end
        _svg_write_group_end(file)
      end

      unless @leftovers_hidden
        _svg_write_group_start(file, id: LAYER_LEFTOVER)

        position = Geom::Point3d.new(
          _to_inch(bar.leftover.px_x),
          _to_inch(0)
        ).transform(unit_transformation)
        size = Geom::Point3d.new(
          _to_inch(bar.leftover.px_length),
          _to_inch(bar.px_width)
        ).transform(unit_transformation)

        _svg_write_tag(file, 'rect', {
          x: _svg_value(position.x),
          y: _svg_value(position.y),
          width: _svg_value(size.x),
          height: _svg_value(size.y),
          stroke: _svg_stroke_color_hex(@leftovers_stroke_color, @leftovers_fill_color),
          fill: _svg_fill_color_hex(@leftovers_fill_color),
        })

        _svg_write_group_end(file)
      end

      unless @cuts_hidden
        _svg_write_group_start(file, id: LAYER_CUT)
        bar.cuts.each do |cut|

          position1 = Geom::Point3d.new(
            _to_inch(cut.px_x),
            0
          ).transform(unit_transformation)
          position2 = Geom::Point3d.new(
            _to_inch(cut.px_x),
            _to_inch(bar.px_width)
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

    def _write_to_dxf_file(file, bar)

      unit_factor = _dxf_get_unit_factor(@unit)
      unit_transformation = Geom::Transformation.scaling(ORIGIN, unit_factor, unit_factor, 1.0)

      bar_size = Geom::Point3d.new(
        _to_inch(bar.px_length),
        _to_inch(bar.px_width)
      ).transform(unit_transformation)

      bar_width = bar_size.x.to_f
      bar_height = bar_size.y.to_f

      min = Geom::Point3d.new
      max = Geom::Point3d.new(bar_width, bar_height)

      layer_defs = []
      layer_defs << DxfLayerDef.new(LAYER_BAR, @bar_stroke_color) unless @sheet_hidden
      layer_defs << DxfLayerDef.new(LAYER_PART, @parts_stroke_color) unless @parts_hidden || @dxf_structure == DXF_STRUCTURE_LAYER
      layer_defs << DxfLayerDef.new(LAYER_LEFTOVER, @leftovers_stroke_color) unless @leftovers_hidden
      layer_defs << DxfLayerDef.new(LAYER_CUT, @cuts_color) unless @cuts_hidden
      layer_defs << DxfLayerDef.new(LAYER_TEXT, @texts_color) unless @parts_hidden || @texts_hidden

      unless @parts_hidden
        depth_layer_defs = []
        bar.parts.uniq { |part| part.id }.each do |part|
          projection_def = _get_part_projection_def(part)
          if projection_def.is_a?(DrawingProjectionDef)
            depth_layer_defs.concat(_dxf_get_projection_def_depth_layer_defs(projection_def,
                                                                             color: @parts_stroke_color,
                                                                             holes_color: @parts_holes_stroke_color,
                                                                             paths_color: @parts_paths_stroke_color,
                                                                             unit_transformation: unit_transformation,
                                                                             prefix: LAYER_PART))
          end
        end
        layer_defs.concat(depth_layer_defs.uniq { |layer_def| layer_def.name })
      end

      fn_part_block_name = lambda do |part|
        _dxf_sanitize_identifier("#{LAYER_PART}_#{part.number.to_s.rjust(3, '_')}#{@use_names ? "_#{part.name}" : ''}")
      end

      _dxf_write_start(file)
      _dxf_write_section_header(file, @unit, min, max)
      _dxf_write_section_classes(file)
      _dxf_write_section_tables(file, min, max, layer_defs) do |owner_id|

        if @dxf_structure == DXF_STRUCTURE_LAYER_AND_BLOCK

          unless @parts_hidden
            bar.parts.uniq { |part| part.id }.each do |part|
              projection_def = _get_part_projection_def(part)
              if projection_def.is_a?(DrawingProjectionDef)
                _dxf_write_projection_def_block_record(file, projection_def, fn_part_block_name.call(part), owner_id)
              else
                _dxf_write_section_tables_block_record(file, fn_part_block_name.call(part), owner_id)
              end
            end
          end

        end

      end
      _dxf_write_section_blocks(file) do

        if @dxf_structure == DXF_STRUCTURE_LAYER_AND_BLOCK

          unless @parts_hidden
            bar.parts.uniq { |part| part.id }.each do |part|

              size = Geom::Point3d.new(
                _to_inch(part.px_length),
                _to_inch(bar.px_width)
              ).transform(unit_transformation)

              width = size.x.to_f
              height = size.y.to_f

              projection_def = _get_part_projection_def(part)
              if projection_def.is_a?(DrawingProjectionDef)

                x_offset = _to_inch(part.px_x_offset)

                transformation = unit_transformation
                transformation *= Geom::Transformation.translation(Geom::Vector3d.new(x_offset, 0))

                _dxf_write_projection_def_block(file, fn_part_block_name.call(part), projection_def,
                                                smoothing: @smoothing,
                                                transformation: transformation,
                                                unit_transformation: unit_transformation,
                                                layer: LAYER_PART) do
                  _dxf_write_label(file, 0, 0, width, height, @use_names ? part.name : part.number, width, height, 0, 0, 0, LAYER_TEXT) unless @texts_hidden
                end

              else

                _dxf_write_section_blocks_block(file, fn_part_block_name.call(part), @_dxf_model_space_id) do
                  _dxf_write_rect(file, 0, 0, width, height, LAYER_PART)
                  _dxf_write_label(file, 0, 0, width, height, @use_names ? part.name : part.number, width, height, 0, 0, 0, LAYER_TEXT) unless @texts_hidden
                end

              end

            end
          end

        end

      end
      _dxf_write_section_entities(file) do

        unless @bar_hidden
          _dxf_write_rect(file, 0, 0, bar_width, bar_height, LAYER_BAR)
        end

        unless @parts_hidden
          bar.parts.each do |part|

            if @dxf_structure == DXF_STRUCTURE_LAYER_AND_BLOCK

              position = Geom::Point3d.new(
                _to_inch(part.px_x),
                0
              ).transform(unit_transformation)

              x = position.x.to_f
              y = position.y.to_f

              _dxf_write_insert(file, fn_part_block_name.call(part), x, y, 0, 1.0, 1.0, 1.0, 0, LAYER_PART)

            else

              position = Geom::Point3d.new(
                _to_inch(part.px_x),
                0
              ).transform(unit_transformation)
              size = Geom::Point3d.new(
                _to_inch(part.px_length),
                _to_inch(bar.px_width)
              ).transform(unit_transformation)

              x = position.x.to_f
              y = position.y.to_f
              width = size.x.to_f
              height = size.y.to_f

              projection_def = _get_part_projection_def(part)
              if projection_def.is_a?(DrawingProjectionDef)

                transformation = unit_transformation
                transformation *= Geom::Transformation.translation(Geom::Vector3d.new(_to_inch(part.px_x) + _to_inch(part.px_x_offset), 0))

                _dxf_write_projection_def_geometry(file, projection_def,
                                                   smoothing: @smoothing,
                                                   transformation: transformation,
                                                   unit_transformation: unit_transformation,
                                                   layer: LAYER_PART)

              else

                _dxf_write_rect(file, x, y, width, height, LAYER_PART)

              end

              _dxf_write_label(file, x, y, width, height, @use_names ? part.name : part.number, width, height, 0, 0, 0, LAYER_TEXT) unless @texts_hidden

            end

          end
        end

        unless @leftovers_hidden

          position = Geom::Point3d.new(
            _to_inch(bar.leftover.px_x),
            0
          ).transform(unit_transformation)
          size = Geom::Point3d.new(
            _to_inch(bar.leftover.px_length),
            _to_inch(bar.px_width)
          ).transform(unit_transformation)

          x = position.x.to_f
          y = position.y.to_f
          width = size.x.to_f
          height = size.y.to_f

          _dxf_write_rect(file, x, y, width, height, LAYER_LEFTOVER)

        end

        unless @cuts_hidden
          bar.cuts.each do |cut|

            position1 = Geom::Point3d.new(
              _to_inch(cut.px_x),
              0
            ).transform(unit_transformation)
            position2 = Geom::Point3d.new(
              _to_inch(cut.px_x),
              _to_inch(bar.px_width)
            ).transform(unit_transformation)

            cut_x1 = position1.x.to_f
            cut_y1 = position1.y.to_f
            cut_x2 = position2.x.to_f
            cut_y2 = position2.y.to_f

            _dxf_write_line(file, cut_x1, cut_y1, cut_x2, cut_y2, LAYER_CUT)

          end
        end

      end
      _dxf_write_section_objects(file)
      _dxf_write_end(file)

    end

    def _get_part_projection_def(part)
      _compute_part_projection_def(@part_drawing_type, part.def.cutlist_part,
                                   ignore_edges: !@include_paths,
                                   merge_holes: @merge_holes,
                                   use_cache: false
      )
    end

  end

end
