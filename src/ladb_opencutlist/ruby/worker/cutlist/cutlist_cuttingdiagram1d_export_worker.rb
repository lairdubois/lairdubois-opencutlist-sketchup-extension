module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/svg_writer_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../utils/color_utils'

  class CutlistCuttingdiagram1dExportWorker

    include SanitizerHelper
    include DxfWriterHelper
    include SvgWriterHelper
    include PixelConverterHelper

    LAYER_SHEET = 'OCL_SHEET'.freeze
    LAYER_PARTS = 'OCL_PARTS'.freeze
    LAYER_LEFTOVERS = 'OCL_LEFTOVERS'.freeze
    LAYER_CUTS = 'OCL_CUTS'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SVG, FILE_FORMAT_DXF ]

    def initialize(settings, cutlist, cuttingdiagram1d)

      @file_format = settings.fetch('file_format', nil)
      @smoothing = settings.fetch('smoothing', false)
      @bar_hidden = settings.fetch('bar_hidden', false)
      @bar_stroke_color = settings.fetch('bar_stroke_color', nil)
      @bar_fill_color = settings.fetch('bar_fill_color', nil)
      @parts_hidden = settings.fetch('parts_hidden', false)
      @parts_stroke_color = settings.fetch('parts_stroke_color', nil)
      @parts_fill_color = settings.fetch('parts_fill_color', nil)
      @leftovers_hidden = settings.fetch('leftovers_hidden', true)
      @leftovers_stroke_color = settings.fetch('leftovers_stroke_color', nil)
      @leftovers_fill_color = settings.fetch('leftovers_fill_color', nil)
      @cuts_hidden = settings.fetch('cuts_hidden', true)
      @cuts_stroke_color = settings.fetch('cuts_stroke_color', nil)
      @hidden_bar_indices = settings.fetch('hidden_bar_indices', [])
      @use_names = settings.fetch('use_names', false)

      @cutlist = cutlist
      @cuttingdiagram1d = cuttingdiagram1d

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @cuttingdiagram1d && @cuttingdiagram1d.def.group
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)

      # Ask for output dir
      dir = UI.select_directory(title: Plugin.instance.get_i18n_string('tab.cutlist.cuttingdiagram.export.title'), directory: '')
      if dir

        group = @cuttingdiagram1d.def.group
        folder = _sanitize_filename("#{group.material_display_name} - #{group.std_dimension}")
        export_path = File.join(dir, folder)

        if File.exists?(export_path)
          if UI.messagebox(Plugin.instance.get_i18n_string('core.messagebox.dir_override', { :target => folder, :parent => File.basename(dir) }), MB_YESNO) == IDYES
            FileUtils.remove_dir(export_path, true)
          else
            return { :cancelled => true }
          end
        end
        Dir.mkdir(export_path)

        bar_index = 1
        @cuttingdiagram1d.bars.each do |bar|
          next if @hidden_bar_indices.include?(bar_index)
          _write_to_path(export_path, bar, bar_index)
          bar_index += bar.count
        end

        return {
          :export_path => export_path
        }
      end

      {
        :cancelled => true
      }
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

      unit_sign, unit_transformation = _svg_get_unit_sign_and_transformation(DimensionUtils.instance.length_unit)

      size = Geom::Point3d.new(
        _to_inch(bar.px_length),
        _to_inch(bar.px_width)
      ).transform(unit_transformation)

      width = _svg_value(size.x)
      height = _svg_value(size.y)

      _svg_write_start(file, 0, 0, width, height, unit_sign)

      unless @bar_hidden

        id = "#{bar.length} x #{bar.width}"

        _svg_write_group_start(file, id: LAYER_SHEET)
        _svg_write_tag(file, 'rect', {
          x: 0,
          y: 0,
          width: width,
          height: height,
          stroke: _svg_stroke_color(@bar_stroke_color, @bar_fill_color),
          fill: _svg_fill_color(@bar_fill_color),
          id: _svg_sanitize_id(id),
          'serif:id': id
        })
        _svg_write_group_end(file)

      end

      unless @parts_hidden
        _svg_write_group_start(file, id: LAYER_PARTS)
        bar.parts.each do |part|

          id = @use_names ? part.name : part.number

          projection_def = @cuttingdiagram1d.def.projection_defs[part.id]
          if projection_def.nil?

            position = Geom::Point3d.new(
              _to_inch(part.px_x),
              0
            ).transform(unit_transformation)
            size = Geom::Point3d.new(
              _to_inch(part.px_length),
              _to_inch(bar.px_width)
            ).transform(unit_transformation)

            _svg_write_tag(file, 'rect', {
              x: _svg_value(position.x),
              y: _svg_value(position.y),
              width: _svg_value(size.x),
              height: _svg_value(size.y),
              stroke: _svg_stroke_color(@parts_stroke_color, @parts_fill_color),
              fill: _svg_fill_color(@parts_fill_color),
              id: _svg_sanitize_id(id),
              'serif:id': id
            })

          else

            part_x = _to_inch(part.px_x)
            part_y = _to_inch(-bar.px_width)
            part_x_offset = _to_inch(part.px_x_offset)

            transformation = unit_transformation
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(part_x + part_x_offset, part_y))

            _svg_write_group_start(file, {
              id: _svg_sanitize_id(id),
              'serif:id': id
            })

            _svg_write_projection_def(file, projection_def, @smoothing, transformation, unit_transformation, unit_sign, @parts_stroke_color, @parts_fill_color)

            _svg_write_group_end(file)

          end

        end
        _svg_write_group_end(file)
      end

      unless @leftovers_hidden
        _svg_write_group_start(file, id: LAYER_LEFTOVERS)

        id = "#{bar.leftover.length}"

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
          stroke: _svg_stroke_color(@leftovers_stroke_color, @leftovers_fill_color),
          fill: _svg_fill_color(@leftovers_fill_color),
          id: _svg_sanitize_id(id),
          'serif:id': id
        })

        _svg_write_group_end(file)
      end

      unless @cuts_hidden
        _svg_write_group_start(file, id: LAYER_CUTS)
        bar.cuts.each do |cut|

          position1 = Geom::Point3d.new(
            _to_inch(cut.px_x),
            0
          ).transform(unit_transformation)
          position2 = Geom::Point3d.new(
            _to_inch(cut.px_x),
            _to_inch(bar.px_width)
          ).transform(unit_transformation)

          id = "x = #{cut.x}"

          _svg_write_tag(file, 'line', {
            x1: _svg_value(position1.x),
            y1: _svg_value(position1.y),
            x2: _svg_value(position2.x),
            y2: _svg_value(position2.y),
            stroke: _svg_stroke_color(@cuts_stroke_color),
            id: _svg_sanitize_id(id),
            'serif:id': id
          })

        end
        _svg_write_group_end(file)
      end

      _svg_write_end(file)

    end

    def _write_to_dxf_file(file, bar)

      unit_transformation = _dxf_get_unit_transformation(DimensionUtils.instance.length_unit)

      bar_size = Geom::Point3d.new(
        _to_inch(bar.px_length),
        _to_inch(bar.px_width)
      ).transform(unit_transformation)

      bar_width = bar_size.x.to_f
      bar_height = bar_size.y.to_f

      layer_defs = []
      layer_defs.push({ :name => LAYER_SHEET, :color => 150 }) unless @bar_hidden
      layer_defs.push({ :name => LAYER_PARTS, :color => 7 }) unless @parts_hidden
      layer_defs.push({ :name => LAYER_LEFTOVERS, :color => 8 }) unless @leftovers_hidden
      layer_defs.push({ :name => LAYER_CUTS, :color => 6 }) unless @cuts_hidden

      _dxf_write_header(file, Geom::Point3d.new, Geom::Point3d.new(bar_width, bar_height, 0), layer_defs)

      _dxf_write(file, 0, 'SECTION')
      _dxf_write(file, 2, 'ENTITIES')

      unless @bar_hidden
        _dxf_write_rect(file, 0, 0, bar_width, bar_height, LAYER_SHEET)
      end

      unless @parts_hidden
        bar.parts.each do |part|

          projection_def = @cuttingdiagram1d.def.projection_defs[part.id]
          if projection_def.nil?

            position = Geom::Point3d.new(
              _to_inch(part.px_x),
              0
            ).transform(unit_transformation)
            size = Geom::Point3d.new(
              _to_inch(part.px_length),
              _to_inch(bar.px_width)
            ).transform(unit_transformation)

            part_x = position.x.to_f
            part_y = position.y.to_f
            part_width = size.x.to_f
            part_height = size.y.to_f

            _dxf_write_rect(file, part_x, part_y, part_width, part_height, LAYER_PARTS)

          else

            part_x = _to_inch(part.px_x)
            part_y = 0
            part_x_offset = _to_inch(part.px_x_offset)

            transformation = unit_transformation
            transformation *= Geom::Transformation.translation(Geom::Vector3d.new(part_x + part_x_offset, part_y))

            _dxf_write_projection_def(file, projection_def, @smoothing, transformation, LAYER_PARTS)

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

        leftover_x = position.x.to_f
        leftover_y = position.y.to_f
        leftover_width = size.x.to_f
        leftover_height = size.y.to_f

        _dxf_write_rect(file, leftover_x, leftover_y, leftover_width, leftover_height, LAYER_LEFTOVERS)

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

          _dxf_write_line(file, cut_x1, cut_y1, cut_x2, cut_y2, LAYER_CUTS)

        end
      end

      _dxf_write(file, 0, 'ENDSEC')

      _dxf_write_footer(file)

    end

  end

end
