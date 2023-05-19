module Ladb::OpenCutList

  class CutlistPartExportToStlWorker

    def initialize(settings, cutlist)

      @part_id = settings.fetch('part_id', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
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
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_stl.title'), @cutlist.dir, definition.name + '.stl')
      if path

        # Force "stl" file extension
        unless path.end_with?('.stl')
          path = path + '.stl'
        end

        begin

          scale = instance_info.scale
          transformation = Geom::Transformation.scaling(scale.x * (part.flipped ? -1 : 1), scale.y, scale.z)

          _write_definition(path, definition, transformation)

          return { :export_path => path }
        rescue => e
          puts e.inspect
          puts e.backtrace
          return { :errors => [ [ 'tab.cutlist.error.failed_export_stl_file', { :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

    # -----

    private

    def _write_definition(path, definition, transformation)

      file = File.new(path , 'w')
      file.puts("solid #{definition.name}")
      _write_entities(file, DimensionUtils.instance.length_to_model_unit_float(1.0.to_l), definition.entities, transformation)
      file.puts("endsolid #{definition.name}")
      file.close

    end

    def _write_entities(file, unit_converter, entities, transformation)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Face)

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
                file.puts("   vertex #{point.x.to_f * unit_converter} #{point.y.to_f * unit_converter} #{point.z.to_f * unit_converter}")
              end
              file.puts("  endloop")
              file.puts(" endfacet")
            end
          end

        elsif entity.is_a?(Sketchup::Group)
          _write_entities(file, entity.entities, transformation * entity.transformation, unit_converter)
        elsif entity.is_a?(Sketchup::ComponentInstance)
          _write_entities(file, entity.definition.entities, transformation * entity.transformation, unit_converter)
        end
      end
    end

  end

end