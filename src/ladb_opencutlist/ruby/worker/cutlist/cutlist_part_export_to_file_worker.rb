module Ladb::OpenCutList

  require_relative '../common/common_export_instance_to_file_worker'

  class CutlistPartExportToFileWorker

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

      # Run export worker
      worker = CommonExportInstanceToFileWorker.new(instance_info, {}, @file_format)
      response = worker.run

      response
    end

  end

end