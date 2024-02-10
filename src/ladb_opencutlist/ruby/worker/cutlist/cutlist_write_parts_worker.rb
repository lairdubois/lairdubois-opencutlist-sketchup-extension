module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../common/common_write_definition_worker'
  require_relative '../common/common_write_drawing2d_worker'
  require_relative '../common/common_write_drawing3d_worker'

  class CutlistWritePartsWorker

    include PartDrawingHelper
    include SanitizerHelper

    def initialize(settings, cutlist)

      @part_ids = settings.fetch('part_ids', nil)
      @file_format = settings.fetch('file_format', nil)
      @part_drawing_type = settings.fetch('part_drawing_type', PART_DRAWING_TYPE_2D_TOP).to_i

      @unit = settings.fetch('unit', nil)
      @anchor = settings.fetch('anchor', false)
      @smoothing = settings.fetch('smoothing', false)
      @merge_holes = settings.fetch('merge_holes', false)
      @include_paths = settings.fetch('include_paths', false)

      @parts_stroke_color = settings.fetch('parts_stroke_color', nil)
      @parts_fill_color = settings.fetch('parts_fill_color', nil)
      @parts_holes_stroke_color = settings.fetch('parts_holes_stroke_color', nil)
      @parts_holes_fill_color = settings.fetch('parts_holes_fill_color', nil)
      @parts_paths_stroke_color = settings.fetch('parts_paths_stroke_color', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve part
      parts = @cutlist.get_real_parts(@part_ids)
      return { :errors => [ 'tab.cutlist.error.unknow_part' ] } if parts.empty?

      # Ask for output dir
      dir = UI.select_directory(title: Plugin.instance.get_i18n_string('tab.cutlist.write.title'), directory: '')
      if dir

        folder_names = []
        parts.select { |part| !part.virtual }.each do |part|

          group = part.group
          folder_name = group.material_display_name
          folder_name = Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') if folder_name.nil? || folder_name.empty?
          folder_name += " - #{group.std_dimension}" unless group.std_dimension.empty?
          folder_name = _sanitize_filename(folder_name)
          folder_path = File.join(dir, folder_name)
          file_name = "#{part.number} - #{_sanitize_filename(part.name)}"

          begin

            unless folder_names.include?(folder_name)
              if File.exist?(folder_path)
                if UI.messagebox(Plugin.instance.get_i18n_string('core.messagebox.dir_override', { :target => folder_name, :parent => File.basename(dir) }), MB_YESNO) == IDYES
                  FileUtils.remove_dir(folder_path, true)
                else
                  return { :cancelled => true }
                end
              end
              Dir.mkdir(folder_path)
              folder_names << folder_name
            end

            # Forward to specific worker for SKP export
            if @file_format == FILE_FORMAT_SKP

              instance_info = part.def.get_one_instance_info
              return { :errors => [ 'tab.cutlist.error.unknow_part' ] } if instance_info.nil?

              response = CommonWriteDefinitionWorker.new({
                'folder_path' => folder_path,
                'file_name' => file_name,
                'definition' => instance_info.definition
              }).run
              return response if !response[:errors].nil? || response[:cancelled]

              next
            end

            case @part_drawing_type
            when PART_DRAWING_TYPE_2D_TOP, PART_DRAWING_TYPE_2D_BOTTOM

              drawing_def = _compute_part_drawing_def(@part_drawing_type, part,
                                                      ignore_edges: !@include_paths,
                                                      origin_position: CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT,
                                                      use_cache: !@include_paths
              )
              return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

              response = CommonWriteDrawing2dWorker.new(drawing_def, {
                'folder_path' => folder_path,
                'file_name' => file_name,
                'file_format' => @file_format,
                'unit' => @unit,
                'anchor' => @anchor,
                'smoothing' => @smoothing,
                'merge_holes' => @merge_holes,
                'parts_stroke_color' => @parts_stroke_color,
                'parts_fill_color' => @parts_fill_color,
                'parts_holes_stroke_color' => @parts_holes_stroke_color,
                'parts_holes_fill_color' => @parts_holes_fill_color,
                'parts_paths_stroke_color' => @parts_paths_stroke_color,
              }).run
              return response if !response[:errors].nil? || response[:cancelled]
            when PART_DRAWING_TYPE_3D

              drawing_def = _compute_part_drawing_def(@part_drawing_type, part,
                                                      origin_position: @anchor ? CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
                                                      use_cache: false
              )
              return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

              response = CommonWriteDrawing3dWorker.new(drawing_def, {
                'folder_path' => folder_path,
                'file_name' => file_name,
                'file_format' => @file_format,
                'unit' => @unit,
                'anchor' => @anchor,
              }).run
              return response if !response[:errors].nil? || response[:cancelled]
            end

          rescue => e
            puts e.inspect
            puts e.backtrace
            return { :errors => [ [ 'core.error.failed_export_to', { :path => folder_path, :error => e.message } ] ] }
          end

        end

        return { :export_path => dir }
      end

    end

  end

end