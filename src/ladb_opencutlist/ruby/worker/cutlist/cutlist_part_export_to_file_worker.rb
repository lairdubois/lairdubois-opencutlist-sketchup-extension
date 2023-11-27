module Ladb::OpenCutList

  require_relative '../common/common_drawing_decomposition_worker'
  require_relative '../common/common_export_drawing2d_worker'
  require_relative '../common/common_export_drawing3d_worker'
  require_relative '../cutlist/cutlist_part_export_to_skp_worker'

  class CutlistPartExportToFileWorker

    DRAWING_TYPE_2D_TOP = '2d-top'.freeze
    DRAWING_TYPE_2D_BOTTOM = '2d-bottom'.freeze
    DRAWING_TYPE_3D = '3d'.freeze

    def initialize(settings, cutlist)

      @part_id = settings.fetch('part_id', nil)
      @file_format = settings.fetch('file_format', nil)
      @drawing_type = settings.fetch('drawing_type', DRAWING_TYPE_2D_TOP)

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

      local_x_axis = part.def.size.oriented_axis(X_AXIS)
      local_y_axis = part.def.size.oriented_axis(Y_AXIS)
      local_z_axis = part.def.size.oriented_axis(Z_AXIS)

      if @drawing_type == DRAWING_TYPE_2D_BOTTOM
        local_x_axis = local_x_axis.reverse
        local_z_axis = local_z_axis.reverse
      end

      drawing_def = CommonDrawingDecompositionWorker.new(instance_info.path, {
        'input_local_x_axis' => local_x_axis,
        'input_local_y_axis' => local_y_axis,
        'input_local_z_axis' => local_z_axis,
        'use_bounds_min_as_origin' => true,
        'ignore_edges' => true
      }).run
      return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

      case @drawing_type

      when DRAWING_TYPE_2D_TOP, DRAWING_TYPE_2D_BOTTOM
        response = CommonExportDrawing2dWorker.new(drawing_def, {
          'file_name' => part.name,
          'file_format' => @file_format,
        }).run
      when DRAWING_TYPE_3D
        response = CommonExportDrawing3dWorker.new(drawing_def, {
          'file_name' => part.name,
          'file_format' => @file_format
        }).run
      end

      response
    end

  end

end