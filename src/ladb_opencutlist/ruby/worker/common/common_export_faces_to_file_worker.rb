module Ladb::OpenCutList

  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/dxf_helper'
  require_relative '../../helper/svg_helper'

  class CommonExportFacesToFileWorker

    include FaceTrianglesHelper
    include DxfHelper
    include SvgHelper

    FILE_FORMAT_DXF = 'dxf'.freeze
    FILE_FORMAT_SVG = 'svg'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_SVG ]

    def initialize(face_infos, options, file_format, file_name = 'FACE')

      @face_infos = face_infos
      @options = options
      @file_format = file_format
      @file_name = file_name

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @face_infos.is_a?(Array)

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{@file_name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)

          success = _write_faces(path, @face_infos, unit_converter ) && File.exist?(path)

          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] } unless success
          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'tab.cutlist.error.failed_export_to_3d_file', { :file_format => @file_format, :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_faces(path, face_infos, unit_converter)

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        _dxf(file, 0, 'SECTION')
        _dxf(file, 2, 'ENTITIES')

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          face.loops.each do |loop|

            _dxf(file, 0, 'POLYLINE')
            _dxf(file, 8, 0)
            _dxf(file, 66, 1)
            _dxf(file, 70, 1) # 1 = This is a closed polyline (or a polygon mesh closed in the M direction)
            _dxf(file, 10, 0.0)
            _dxf(file, 20, 0.0)
            _dxf(file, 30, 0.0)

            loop.vertices.each do |vertex|
              point = vertex.position.transform(transformation)
              _dxf(file, 0, 'VERTEX')
              _dxf(file, 8, 0)
              _dxf(file, 10, _convert(point.x, unit_converter))
              _dxf(file, 20, _convert(point.y, unit_converter))
              _dxf(file, 30, 0.0)
              _dxf(file, 70, 32) # 32 = 3D polyline vertex
            end

            _dxf(file, 0, 'SEQEND')

          end

        end

        _dxf(file, 0, 'ENDSEC')
        _dxf(file, 0, 'EOF')

      when FILE_FORMAT_SVG

        bounds = Geom::BoundingBox.new
        face_infos.each do |face_info|
          bounds.add(_compute_children_faces_triangles([ face_info.face ], face_info.transformation))
        end

        # Tweak unit converter to restrict to SVG compatible units (in, mm, cm)
        case DimensionUtils.instance.length_unit
        when DimensionUtils::INCHES
          unit_converter = 1.0
          unit_sign = 'in'
        when DimensionUtils::CENTIMETER
          unit_converter = 1.0.to_cm
          unit_sign = 'cm'
        else
          unit_converter = 1.0.to_mm
          unit_sign = 'mm'
        end

        width = _convert(bounds.width, unit_converter)
        height = _convert(bounds.height, unit_converter)

        _svg_start(file, width, height, unit_sign)

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          outside = []
          pockets = []
          face.loops.each do |loop|
            coords = []
            loop.vertices.each do |vertex|
              point = vertex.position.transform(transformation)
              coords << "#{_convert(point.x, unit_converter)},#{height - _convert(point.y, unit_converter)}"
            end
            data = "M#{coords.join('L')}Z"
            outside << data
            pockets << data unless loop.outer?
          end
          _svg_path(file, outside.join, '#000000')
          pockets.each do |pocket|
            _svg_path(file, pocket, '#7F7F7F')
          end

        end

        _svg_end(file)

      end

      # Close output file
      file.close

      true
    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

  end

end