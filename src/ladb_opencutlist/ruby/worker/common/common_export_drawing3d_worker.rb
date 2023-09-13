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

    LAYER_DRAWING = 'OCL_DRAWING'.freeze
    LAYER_GUIDES = 'OCL_GUIDES'.freeze

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
      path = UI.savepanel(Plugin.instance.get_i18n_string('core.savepanel.export_to_file', { :file_format => @file_format.upcase }), '', "#{@file_name}.#{@file_format}")
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

          success = _write_3d(path, @drawing_def.face_manipulators, @drawing_def.edge_manipulators, unit_converter) && File.exist?(path)

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

    def _write_3d(path, face_manipulators, edge_manipulators, unit_converter)

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_DXF

        layer_defs = []
        layer_defs.push({ :name => LAYER_DRAWING, :color => 7 }) unless face_manipulators.empty?
        layer_defs.push({ :name => LAYER_GUIDES, :color => 150 }) unless edge_manipulators.empty?

        _dxf_write_header(file, _convert_point(@drawing_def.bounds.min, unit_converter), _convert_point(@drawing_def.bounds.max, unit_converter), layer_defs)

        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')

        face_manipulators.each do |face_manipulator|

          # Export face to POLYFACE

          mesh = face_manipulator.mesh

          polygons = mesh.polygons
          points = mesh.points

          # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-ABF6B778-BE20-4B49-9B58-A94E64CEFFF3

          _dxf_write(file, 0, 'POLYLINE')
          id = _dxf_write_id(file)
          _dxf_write_owner_id(file, @_dxf_model_space_id)
          _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
          _dxf_write(file, 8, LAYER_DRAWING) # Layer
          _dxf_write_sub_classes(file, [ 'AcDbPolygonMesh' ])
          _dxf_write(file, 66, 1) # Deprecated
          _dxf_write(file, 10, 0.0)
          _dxf_write(file, 20, 0.0)
          _dxf_write(file, 30, 0.0)
          _dxf_write(file, 70, 64) # 64 = The polyline is a polyface mesh
          _dxf_write(file, 71, points.length) # Polygon mesh M vertex count
          _dxf_write(file, 72, 1) # Polygon mesh N vertex count

          points.each do |point|

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write_id(file)
            _dxf_write_owner_id(file, id)
            _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
            _dxf_write(file, 8, LAYER_DRAWING) # Layer
            _dxf_write_sub_classes(file, [ 'AcDbVertex', 'AcDbPolygonMeshVertex' ])
            _dxf_write(file, 10, _convert(point.x, unit_converter))
            _dxf_write(file, 20, _convert(point.y, unit_converter))
            _dxf_write(file, 30, _convert(point.z, unit_converter))
            _dxf_write(file, 70, 64 ^ 128) # 64 = 3D polygon mesh, 128 = Polyface mesh vertex

          end

          polygons.each do |polygon|

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write_id(file)
            _dxf_write_owner_id(file, id)
            _dxf_write_sub_classes(file, [ 'AcDbVertex', 'AcDbPolygonMeshVertex' ])
            _dxf_write(file, 8, LAYER_DRAWING)
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

        edge_manipulators.each do |edge_manipulator|

          point1 = edge_manipulator.start_point
          point2 = edge_manipulator.end_point

          x1 = _convert(point1.x, unit_converter)
          y1 = _convert(point1.y, unit_converter)
          x2 = _convert(point2.x, unit_converter)
          y2 = _convert(point2.y, unit_converter)

          _dxf_write_line(file, x1, y1, x2, y2, LAYER_GUIDES)

        end

        _dxf_write(file, 0, 'ENDSEC')

        _dxf_write_footer(file)

      when FILE_FORMAT_STL

        file.puts("solid #{@file_name}")

        face_manipulators.each do |face_manipulator|

          mesh = face_manipulator.mesh
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

        face_manipulators.each do |face_manipulator|

          mesh = face_manipulator.mesh
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