module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/stl_writer_helper'
  require_relative '../../helper/obj_writer_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../../model/drawing/drawing_def'

  class CommonWriteDrawing3dWorker

    include StlWriterHelper
    include ObjWriterHelper
    include DxfWriterHelper
    include SanitizerHelper

    LAYER_PART = 'OCL_PART'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_STL, FILE_FORMAT_OBJ ]

    def initialize(drawing_def,

                   folder_path: nil,
                   file_name: 'PART',
                   file_format: nil,

                   unit: nil,
                   switch_yz: false

    )

      @drawing_def = drawing_def

      @folder_path = folder_path
      @file_name = _sanitize_filename(file_name)
      @file_format = file_format

      @unit = unit
      @switch_yz = switch_yz

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      # Open save panel if needed
      if @folder_path.nil? || !File.exist?(@folder_path)
        path = UI.savepanel(PLUGIN.get_i18n_string('core.savepanel.export_to_file', { :file_format => @file_format.upcase }), '', "#{@file_name}.#{@file_format}")
      else
        path = File.join(@folder_path, "#{@file_name}.#{@file_format}")
      end
      if path

        # Force "file_format" file extension
        path = "#{path}.#{@file_format}" unless path.end_with?(".#{@file_format}")

        begin

          # Up axis
          @drawing_def.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)) if @switch_yz

          # Open output file
          file = File.new(path , 'w')

          case @file_format
          when FILE_FORMAT_STL
            _write_to_stl_file(file)
          when FILE_FORMAT_OBJ
            _write_to_obj_file(file)
          end

          # Close output file
          file.close

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

  end

end