module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative 'cutlist_part_export_to_skp_worker'
  require_relative '../common/common_export_drawing2d_worker'
  require_relative '../common/common_export_drawing3d_worker'

  class CutlistPartExportToFileWorker

    include PartDrawingHelper

    def initialize(settings, cutlist)

      @part_id = settings.fetch('part_id', nil)
      @file_format = settings.fetch('file_format', nil)
      @part_drawing_type = settings.fetch('part_drawing_type', PART_DRAWING_TYPE_2D_TOP).to_i

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

      instance_info = part.def.get_one_instance_info
      return { :errors => [ 'tab.cutlist.error.unknow_part' ] } if instance_info.nil?

      # Forward to specific worker for SKP export
      if @file_format == FILE_FORMAT_SKP

        return CutlistPartExportToSkpWorker.new({
          'definition_id' => instance_info.definition.name
        }).run

      end

      drawing_def = _compute_part_drawing_def(@part_drawing_type, part)
      return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

      case @part_drawing_type

      when PART_DRAWING_TYPE_2D_TOP, PART_DRAWING_TYPE_2D_BOTTOM
        response = CommonExportDrawing2dWorker.new(drawing_def, {
          'file_name' => part.name,
          'file_format' => @file_format,
        }).run
      when PART_DRAWING_TYPE_3D
        response = CommonExportDrawing3dWorker.new(drawing_def, {
          'file_name' => part.name,
          'file_format' => @file_format
        }).run
      end

      response
    end

  end

end