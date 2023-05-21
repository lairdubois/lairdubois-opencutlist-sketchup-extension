module Ladb::OpenCutList

  class CommonExportDefinitionTo3dWorker

    FILE_FORMAT_SKP = 'skp'.freeze
    FILE_FORMAT_STL = 'stl'.freeze
    FILE_FORMAT_OBJ = 'obj'.freeze
    FILE_FORMAT_DXF = 'dxf'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SKP, FILE_FORMAT_STL, FILE_FORMAT_OBJ, FILE_FORMAT_DXF ]

    def initialize(definition, transformation, file_format)

      @definition = definition
      @transformation = transformation
      @file_format = file_format

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'default.error' ] } unless @definition

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{@definition.name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          success = _write_definition(path, @definition, @transformation, DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)) && File.exist?(path)

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

    def _write_definition(path, definition, transformation, unit_converter)

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
        _dxf(file, 0, 'SECTION')
        _dxf(file, 2, 'ENTITIES')
      end

      # Write faces
      _write_entities(file, definition.entities, transformation, unit_converter)

      # Write footer
      case @file_format
      when FILE_FORMAT_STL
        file.puts("endsolid #{definition.name}")
      when FILE_FORMAT_DXF
        _dxf(file, 0, 'ENDSEC')
        _dxf(file, 0, 'EOF')
      end

      # Close output file
      file.close

      true
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

            _dxf(file, 0, 'POLYLINE')
            _dxf(file, 8, 0) # Layer
            _dxf(file, 66, 1)
            _dxf(file, 10, 0.0)
            _dxf(file, 20, 0.0)
            _dxf(file, 30, 0.0)
            _dxf(file, 70, 64) # 64 = The polyline is a polyface mesh
            _dxf(file, 71, points.length) # Polygon mesh M vertex count
            _dxf(file, 72, 1) # Polygon mesh N vertex count

            points.each do |point|

              _dxf(file, 0, 'VERTEX')
              _dxf(file, 8, 0) # Layer
              _dxf(file, 10, _convert(point.x, unit_converter))
              _dxf(file, 20, _convert(point.y, unit_converter))
              _dxf(file, 30, _convert(point.z, unit_converter))
              _dxf(file, 70, 64 ^ 128) # 64 = 3D polygon mesh, 128 = Polyface mesh vertex

            end

            polygons.each do |polygon|

              _dxf(file, 0, 'VERTEX')
              _dxf(file, 8, 0) # Layer
              _dxf(file, 10, 0.0)
              _dxf(file, 20, 0.0)
              _dxf(file, 30, 0.0)
              _dxf(file, 70, 128) # 128 = Polyface mesh vertex
              _dxf(file, 71, polygon[0]) # 71 = Polyface mesh vertex index
              _dxf(file, 72, polygon[1]) # 72 = Polyface mesh vertex index
              _dxf(file, 73, polygon[2]) # 73 = Polyface mesh vertex index

            end

            _dxf(file, 0, 'SEQEND')

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

    def _dxf(file, code, value)
      file.puts(code.to_s)
      file.puts(value.to_s)
    end

  end

end