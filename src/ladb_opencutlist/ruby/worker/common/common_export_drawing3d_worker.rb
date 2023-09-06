module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../utils/color_utils'
  require_relative '../../model/cutlist/drawing_def'

  class CommonExportDrawing3dWorker

    include FaceTrianglesHelper
    include DxfWriterHelper
    include SanitizerHelper

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_DXF, FILE_FORMAT_STL, FILE_FORMAT_OBJ ]

    def initialize(drawing_def, settings)

      @drawing_def = drawing_def

      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{@file_name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          case @unit
          when DimensionUtils::INCHES
            unit_converter = 1.0
          when DimensionUtils::FEET
            unit_converter = 1.0.to_l.to_feet
          when DimensionUtils::YARD
            unit_converter = 1.0.to_l.to_yard
          when DimensionUtils::MILLIMETER
            unit_converter = 1.0.to_l.to_mm
          when DimensionUtils::CENTIMETER
            unit_converter = 1.0.to_l.to_cm
          when DimensionUtils::METER
            unit_converter = 1.0.to_l.to_m
          else
            unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)
          end

          success = _write_3d(path, @drawing_def.face_infos, @drawing_def.edge_infos, unit_converter) && File.exist?(path)

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

    def _write_3d(path, face_infos, edge_infos, unit_converter)

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        _dxf_write_header(file, _convert_point(@drawing_def.bounds.min, unit_converter), _convert_point(@drawing_def.bounds.max, unit_converter), [
          { :name => 'OCL_DRAWING' },
          { :name => 'OCL_GUIDE', :color => 4 }
        ])

        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          # Export face to POLYFACE

          mesh = face.mesh(0) # PolygonMeshPoints
          mesh.transform!(transformation)

          polygons = mesh.polygons
          points = mesh.points

          # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-ABF6B778-BE20-4B49-9B58-A94E64CEFFF3

          _dxf_write(file, 0, 'POLYLINE')
          _dxf_write(file, 8, 0) # Layer
          _dxf_write(file, 66, 1) # Deprecated
          _dxf_write(file, 70, 64) # 64 = The polyline is a polyface mesh
          _dxf_write(file, 71, points.length) # Polygon mesh M vertex count
          _dxf_write(file, 72, 1) # Polygon mesh N vertex count

          points.each do |point|

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write(file, 8, 0) # Layer
            _dxf_write(file, 10, _convert(point.x, unit_converter))
            _dxf_write(file, 20, _convert(point.y, unit_converter))
            _dxf_write(file, 30, _convert(point.z, unit_converter))
            _dxf_write(file, 70, 64 ^ 128) # 64 = 3D polygon mesh, 128 = Polyface mesh vertex

          end

          polygons.each do |polygon|

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write(file, 8, 'OCL_DRAWING')
            _dxf_write(file, 10, 0.0)
            _dxf_write(file, 20, 0.0)
            _dxf_write(file, 30, 0.0)
            _dxf_write(file, 70, 128) # 128 = Polyface mesh vertex
            _dxf_write(file, 71, polygon[0]) # 71 = Polyface mesh vertex index
            _dxf_write(file, 72, polygon[1]) # 72 = Polyface mesh vertex index
            _dxf_write(file, 73, polygon[2]) # 73 = Polyface mesh vertex index

          end

          _dxf_write(file, 0, 'SEQEND')

        end

        edge_infos.each do |edge_info|

          edge = edge_info.edge
          transformation = edge_info.transformation

          point1 = edge.start.position.transform(transformation)
          point2 = edge.end.position.transform(transformation)

          x1 = _convert(point1.x, unit_converter)
          y1 = _convert(point1.y, unit_converter)
          x2 = _convert(point2.x, unit_converter)
          y2 = _convert(point2.y, unit_converter)

          _dxf_write_line(file, x1, y1, x2, y2, 'OCL_GUIDE')

        end

        _dxf_write(file, 0, 'ENDSEC')
        _dxf_write(file, 0, 'EOF')

      when FILE_FORMAT_STL

        file.puts("solid #{@file_name}")

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          mesh = face.mesh(4) # PolygonMeshPoints | PolygonMeshNormals
          mesh.transform!(transformation)
          polygons = mesh.polygons
          polygons.each do |polygon|
            if polygon.length == 3
              normal = mesh.normal_at(polygon[0].abs)
              file.puts(" facet normal #{normal.x} #{normal.y} #{normal.z}")
              file.puts("  outer loop")
              3.times do |index|
                point = mesh.point_at(polygon[index].abs)
                file.puts("   vertex #{_convert(point.x, unit_converter)} #{_convert(point.y, unit_converter)} #{_convert(point.z, unit_converter)}")
              end
              file.puts("  endloop")
              file.puts(" endfacet")
            end
          end

        end

        file.puts("endsolid #{@file_name}")

      when FILE_FORMAT_OBJ

        file.puts("g #{@file_name}")

        face_infos.each do |face_info|

          face = face_info.face
          transformation = face_info.transformation

          mesh = face.mesh(4) # PolygonMeshPoints | PolygonMeshNormals
          mesh.transform!(transformation)
          polygons = mesh.polygons
          polygons.each do |polygon|
            if polygon.length == 3
              normal = mesh.normal_at(polygon[0].abs)
              file.puts("vn #{normal.x} #{normal.y} #{normal.z}")
              3.times do |index|
                point = mesh.point_at(polygon[index].abs)
                file.puts("v #{_convert(point.x, unit_converter)} #{_convert(point.y, unit_converter)} #{_convert(point.z, unit_converter)}")
              end
              file.puts("f -3//-1 -2//-1 -1//-1")
            end
          end

        end

      end

      # Close output file
      file.close

      true
    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

    def _convert_point(point, unit_converter, precision = 6)
      point.x = _convert(point.x, unit_converter, precision)
      point.y = _convert(point.y, unit_converter, precision)
      point.z = _convert(point.z, unit_converter, precision)
      point
    end

  end

end