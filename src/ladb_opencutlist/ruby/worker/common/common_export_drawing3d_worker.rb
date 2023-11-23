module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/stl_writer_helper'
  require_relative '../../helper/obj_writer_helper'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../model/drawing/drawing_def'

  class CommonExportDrawing3dWorker

    include StlWriterHelper
    include ObjWriterHelper
    include DxfWriterHelper
    include SanitizerHelper

    LAYER_PART = 'OCL_PART'.freeze
    LAYER_GUIDE = 'OCL_GUIDE'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_STL, FILE_FORMAT_OBJ, FILE_FORMAT_DXF ]

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @file_name = _sanitize_filename(settings.fetch('file_name', 'PART'))
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

          _write_to_path(path)

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

    def _write_to_path(path)

      # Open output file
      file = File.new(path , 'w')

      case @file_format
      when FILE_FORMAT_STL
        _write_to_stl_file(file)
      when FILE_FORMAT_OBJ
        _write_to_obj_file(file)
      when FILE_FORMAT_DXF
        _write_to_dxf_file(file)
      end

      # Close output file
      file.close

    end

    def _write_to_stl_file(file)

      unit_transformation = _stl_get_unit_transformation(@unit)

      _stl_write_solid_start(file, @file_name)

      @drawing_def.face_manipulators.each do |face_manipulator|

        mesh = face_manipulator.mesh
        polygons = mesh.polygons
        polygons.each do |polygon|
          if polygon.length == 3
            normal = mesh.normal_at(polygon[0].abs)
            _stl_write_facet_start(file, normal.x, normal.y, normal.z)
            _stl_write_loop_start(file)
            3.times do |index|
              point = mesh.point_at(polygon[index].abs).transform(unit_transformation)
              _stl_write_vertex(file, point.x, point.y, point.z)
            end
            _stl_write_loop_end(file)
            _stl_write_facet_end(file)
          end
        end

      end

      _stl_write_solid_end(file, @file_name)

    end

    def _write_to_obj_file(file)

      unit_transformation = _obj_get_unit_transformation(@unit)

      _obj_write_group(file, @file_name)

      @drawing_def.face_manipulators.each do |face_manipulator|

        mesh = face_manipulator.mesh
        polygons = mesh.polygons
        polygons.each do |polygon|
          if polygon.length == 3
            normal = mesh.normal_at(polygon[0].abs)
            _obj_write_normal(file, normal.x, normal.y, normal.z)
            3.times do |index|
              point = mesh.point_at(polygon[index].abs).transform(unit_transformation)
              _obj_write_vertex(file, point.x, point.y, point.z)
            end
            _obj_write(file, 'f', '-3//-1 -2//-1 -1//-1')
          end
        end

      end

    end

    def _write_to_dxf_file(file)

      unit_transformation = _dxf_get_unit_transformation(@unit, true)

      layer_defs = []
      layer_defs.push({ :name => LAYER_PART, :color => 7 }) unless @drawing_def.face_manipulators.empty?
      layer_defs.push({ :name => LAYER_GUIDE, :color => 150 }) unless @drawing_def.edge_manipulators.empty?

      min = @drawing_def.bounds.min.transform(unit_transformation)
      max = @drawing_def.bounds.max.transform(unit_transformation)

      _dxf_write_start(file)
      _dxf_write_section_header(file, @unit, min, max)
      _dxf_write_section_classes(file)
      _dxf_write_section_tables(file, min, max, layer_defs)
      _dxf_write_section_blocks(file)
      _dxf_write_section_entities(file) do

        @drawing_def.face_manipulators.each do |face_manipulator|

          # Export face to POLYFACE

          mesh = face_manipulator.mesh

          polygons = mesh.polygons
          points = mesh.points

          # Docs : https://help.autodesk.com/view/OARXMAC/2024/FRA/?guid=GUID-ABF6B778-BE20-4B49-9B58-A94E64CEFFF3

          _dxf_write(file, 0, 'POLYLINE')
          id = _dxf_write_id(file)
          _dxf_write_owner_id(file, @_dxf_model_space_id)
          _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
          _dxf_write(file, 8, LAYER_PART) # Layer
          _dxf_write_sub_classes(file, [ 'AcDbPolyFaceMesh' ])
          _dxf_write(file, 66, 1) # Deprecated
          _dxf_write(file, 10, 0.0)
          _dxf_write(file, 20, 0.0)
          _dxf_write(file, 30, 0.0)
          _dxf_write(file, 70, 64) # 64 = The polyline is a polyface mesh
          _dxf_write(file, 71, points.length) # Polygon mesh M vertex count
          _dxf_write(file, 72, polygons.length) # Polygon mesh N vertex count

          points.each do |point|

            point = point.transform(unit_transformation)

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write_id(file)
            _dxf_write_owner_id(file, id)
            _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
            _dxf_write(file, 8, LAYER_PART) # Layer
            _dxf_write_sub_classes(file, [ 'AcDbVertex', 'AcDbPolyFaceMeshVertex' ])
            _dxf_write(file, 10, point.x)
            _dxf_write(file, 20, point.y)
            _dxf_write(file, 30, point.z)
            _dxf_write(file, 70, 64 ^ 128) # 64 = 3D polygon mesh, 128 = Polyface mesh vertex

          end

          polygons.each do |polygon|

            _dxf_write(file, 0, 'VERTEX')
            _dxf_write_id(file)
            _dxf_write_owner_id(file, id)
            _dxf_write_sub_classes(file, [ 'AcDbEntity' ])
            _dxf_write(file, 8, LAYER_PART)
            _dxf_write_sub_classes(file, [ 'AcDbFaceRecord' ])
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

        @drawing_def.edge_manipulators.each do |edge_manipulator|

          point1 = edge_manipulator.start_point.transform(unit_transformation)
          point2 = edge_manipulator.end_point.transform(unit_transformation)

          x1 = point1.x
          y1 = point1.y
          x2 = point2.x
          y2 = point2.y

          _dxf_write_line(file, x1, y1, x2, y2, LAYER_GUIDE)

        end

      end
      _dxf_write_section_objects(file)
      _dxf_write_end(file)

    end

  end

end