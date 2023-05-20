module Ladb::OpenCutList

  require_relative '../common/common_export_definition_to_3d_worker'

  class CutlistPartExportTo3dWorker

    def initialize(settings, cutlist)

      @part_id = settings.fetch('part_id', nil)
      @file_format = settings.fetch('file_format', nil)

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

      # Compute transformation
      scale = instance_info.scale
      transformation = Geom::Transformation.scaling(scale.x * (part.flipped ? -1 : 1), scale.y, scale.z)

      # Run export worker
      worker = CommonExportDefinitionTo3dWorker.new(definition, transformation, @file_format)
      response = worker.run

      response
    end

  end

end