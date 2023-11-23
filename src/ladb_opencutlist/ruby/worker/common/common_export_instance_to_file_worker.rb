module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../model/cutlist/instance_info'
  require_relative '../../helper/dxf_writer_helper'
  require_relative '../../helper/sanitizer_helper'

  class CommonExportInstanceToFileWorker

    include DxfWriterHelper
    include SanitizerHelper

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SKP, FILE_FORMAT_STL, FILE_FORMAT_OBJ, FILE_FORMAT_DXF ]

    def initialize(instance_info, settings)

      @instance_info = instance_info

      @file_name = _sanitize_filename(settings.fetch('file_name', 'FACE'))
      @file_format = settings.fetch('file_format', nil)
      @unit = settings.fetch('unit', nil)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @instance_info.is_a?(InstanceInfo)

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

          _write_instance(path, @instance_info, unit_converter) && File.exist?(path)

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

    def _write_instance(path, instance_info, unit_converter)

      definition = instance_info.definition
      transformation = instance_info.transformation

      if @file_format == FILE_FORMAT_SKP

        # TODO use transformation
        return definition.save_as(path)

      end

      # Open output file
      file = File.new(path , 'w')

      # Write header
      case @file_format
      when FILE_FORMAT_STL
        file.puts("solid #{definition.name}")
      when FILE_FORMAT_OBJ
        file.puts("g #{definition.name}")
      when FILE_FORMAT_DXF
        _dxf_write(file, 0, 'SECTION')
        _dxf_write(file, 2, 'ENTITIES')
      end

      # Write faces
      _write_entities(file, definition.entities, transformation, unit_converter)

      # Write footer
      case @file_format
      when FILE_FORMAT_STL
        file.puts("endsolid #{definition.name}")
      when FILE_FORMAT_DXF
        _dxf_write(file, 0, 'ENDSEC')
        _dxf_write(file, 0, 'EOF')
      end

      # Close output file
      file.close

    end

    def _write_entities(file, entities, transformation, unit_converter)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Face)

          case @file_format
          when FILE_FORMAT_STL

            mesh = entity.mesh(4) # PolygonMeshPoints | PolygonMeshNormals
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

          when FILE_FORMAT_OBJ

            mesh = entity.mesh(4) # PolygonMeshPoints | PolygonMeshNormals
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

          when FILE_FORMAT_DXF

            # Export face to POLYFACE

            mesh = entity.mesh(0) # PolygonMeshPoints
            mesh.transform!(transformation)
            polygons = mesh.polygons
            points = mesh.points

            _dxf_write(file, 0, 'POLYLINE')
            _dxf_write(file, 8, 0) # Layer
            _dxf_write(file, 66, 1)
            _dxf_write(file, 10, 0.0)
            _dxf_write(file, 20, 0.0)
            _dxf_write(file, 30, 0.0)
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
              _dxf_write(file, 8, 0) # Layer
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

        elsif entity.is_a?(Sketchup::Group)
          _write_entities(file, entity.entities, transformation * entity.transformation, unit_converter)
        elsif entity.is_a?(Sketchup::ComponentInstance)
          _write_entities(file, entity.definition.entities, transformation * entity.transformation, unit_converter)
        end
      end
    end

    def _convert(value, unit_converter, precision = 6)
      (value.to_f * unit_converter).round(precision)
    end

  end

end