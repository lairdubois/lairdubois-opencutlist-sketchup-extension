module Ladb::OpenCutList

  class CutlistPartExportTo3dWorker

    FILE_FORMAT_SKP = 'skp'.freeze
    FILE_FORMAT_STL = 'stl'.freeze
    FILE_FORMAT_OBJ = 'obj'.freeze
    FILE_FORMAT_DXF = 'dxf'.freeze

    SUPPORTED_FILE_FORMATS = [ FILE_FORMAT_SKP, FILE_FORMAT_STL, FILE_FORMAT_OBJ, FILE_FORMAT_DXF ]

    def initialize(settings, cutlist)

      @part_id = settings.fetch('part_id', nil)
      @file_format = settings.fetch('file_format', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'default.error' ] } unless SUPPORTED_FILE_FORMATS.include?(@file_format)
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve part
      parts = @cutlist.get_real_parts([ @part_id ])
      return { :errors => [ 'tab.cutlist.error.unknow_part' ] } if parts.empty?
      part = parts.first
      instance_info = part.def.instance_infos.values.first

      # Fetch definition
      definitions = model.definitions
      definition = definitions[part.def.definition_id]

      return { :errors => [ 'tab.cutlist.error.definition_not_found' ] } unless definition

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_3d.title', { :file_format => @file_format }), '', "#{definition.name}.#{@file_format}")
      if path

        # Force "file_format" file extension
        unless path.end_with?(".#{@file_format}")
          path = "#{path}.#{@file_format}"
        end

        begin

          scale = instance_info.scale
          transformation = Geom::Transformation.scaling(scale.x * (part.flipped ? -1 : 1), scale.y, scale.z)
          unit_converter = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)

          success = _write_definition(path, definition, transformation, unit_converter) && File.exist?(path)

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
        file.puts(" 0\nSECTION\n 2\nENTITIES")
      end

      # Write faces
      _write_entities(file, definition.entities, transformation, unit_converter)

      # Write footer
      case @file_format
      when FILE_FORMAT_STL
        file.puts("endsolid #{definition.name}")
      when FILE_FORMAT_DXF
        file.puts(" 0\nENDSEC\n 0\nEOF")
      end

      # Close output file
      file.close

      return true
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

            mesh = entity.mesh(0) # PolygonMeshPoints
            mesh.transform!(transformation)
            polygons = mesh.polygons
            polygons.each do |polygon|
              if polygon.length > 2
                flags = 0
                file.puts( "  0\n3DFACE\n 8\n#{entity.layer.name}")
                for j in 0..polygon.length do
                  if j == polygon.length
                    count = polygon.length - 1
                  else
                    count = j
                  end
                  # Retrieve edge visibility
                  if polygon[count] < 0
                    flags += 2**j
                  end
                  point = mesh.point_at(polygon[count].abs)
                  file.puts("#{(10+j)}\n#{_convert(point.x, unit_converter)}")
                  file.puts("#{(20+j)}\n#{_convert(point.y, unit_converter)}")
                  file.puts("#{(30+j)}\n#{_convert(point.z, unit_converter)}")
                end
                # Set edge visibiliy flags
                file.puts("70\n#{flags}")
              end
            end

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