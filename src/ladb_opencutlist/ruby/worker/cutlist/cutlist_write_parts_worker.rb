module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/sanitizer_helper'
  require_relative '../common/common_write_definition_worker'
  require_relative '../common/common_write_drawing2d_worker'
  require_relative '../common/common_write_drawing3d_worker'

  class CutlistWritePartsWorker

    include PartDrawingHelper
    include SanitizerHelper

    def initialize(cutlist,

                   part_ids: ,
                   file_format: ,
                   part_drawing_type: PART_DRAWING_TYPE_2D_TOP,

                   unit: Length::Millimeter,
                   use_count: false,
                   anchor: false,
                   switch_yz: false,
                   smoothing: false,
                   merge_holes: false,
                   merge_holes_overflow: 0,
                   include_paths: false,

                   parts_stroke_color: nil,
                   parts_fill_color: nil,
                   parts_depths_stroke_color: nil,
                   parts_depths_fill_color: nil,
                   parts_holes_stroke_color: nil,
                   parts_holes_fill_color: nil,
                   parts_paths_stroke_color: nil,
                   parts_paths_fill_color: nil

    )

      @cutlist = cutlist

      @part_ids = part_ids
      @file_format = file_format
      @part_drawing_type = part_drawing_type.to_i

      @unit = unit
      @use_count = use_count
      @anchor = anchor
      @switch_yz = switch_yz
      @smoothing = smoothing
      @merge_holes = merge_holes
      @merge_holes_overflow = (@merge_holes ? merge_holes_overflow : 0).to_l
      @include_paths = include_paths

      @parts_stroke_color = parts_stroke_color
      @parts_fill_color = parts_fill_color
      @parts_depths_stroke_color = parts_depths_stroke_color
      @parts_depths_fill_color = parts_depths_fill_color
      @parts_holes_stroke_color = parts_holes_stroke_color
      @parts_holes_fill_color = parts_holes_fill_color
      @parts_paths_stroke_color = parts_paths_stroke_color
      @parts_paths_fill_color = parts_paths_fill_color

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
      dir = UI.select_directory(title: PLUGIN.get_i18n_string('tab.cutlist.write.title'), directory: '')
      if dir

        folder_names = []
        parts.each do |part|

          # Ignore virtual parts
          next if part.virtual

          count = @use_count ? part.count : 1
          group = part.group
          folder_name = group.material_display_name
          folder_name = PLUGIN.get_i18n_string('tab.cutlist.material_undefined') if folder_name.nil? || folder_name.empty?
          folder_name += " - #{group.std_dimension}" unless group.std_dimension.empty?
          folder_name = _sanitize_filename(folder_name)
          folder_path = File.join(dir, folder_name)

          count.times do |i|

            file_name = "#{part.number} - #{_sanitize_filename(part.name)}"
            file_name += " - #{i + 1} of #{count}" if @use_count

            begin

            unless folder_names.include?(folder_name)
              if File.exist?(folder_path)
                if UI.messagebox(PLUGIN.get_i18n_string('core.messagebox.dir_override', { :target => folder_name, :parent => File.basename(dir) }), MB_YESNO) == IDYES
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

              response = CommonWriteDefinitionWorker.new(instance_info.definition,
                folder_path: folder_path,
                file_name: file_name
              ).run
              return response if !response[:errors].nil? || response[:cancelled]

              next
            end

            case @part_drawing_type
            when PART_DRAWING_TYPE_2D_TOP, PART_DRAWING_TYPE_2D_BOTTOM,
              PART_DRAWING_TYPE_2D_LEFT, PART_DRAWING_TYPE_2D_RIGHT,
              PART_DRAWING_TYPE_2D_FRONT, PART_DRAWING_TYPE_2D_BACK

              drawing_def = _compute_part_drawing_def(@part_drawing_type, part,
                                                      ignore_edges: !@include_paths,
                                                      origin_position: CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT,
                                                      use_cache: !@include_paths
              )
              return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

              response = CommonWriteDrawing2dWorker.new(drawing_def,
                                                        folder_path: folder_path,
                                                        file_name: file_name,
                                                        file_format: @file_format,
                                                        unit: @unit,
                                                        anchor: @anchor,
                                                        smoothing: @smoothing,
                                                        merge_holes: @merge_holes,
                                                        merge_holes_overflow: @merge_holes_overflow,
                                                        mask: _compute_part_mask(@part_drawing_type, part, drawing_def),
                                                        parts_stroke_color: @parts_stroke_color,
                                                        parts_fill_color: @parts_fill_color,
                                                        parts_depths_stroke_color: @parts_depths_stroke_color,
                                                        parts_depths_fill_color: @parts_depths_fill_color,
                                                        parts_holes_stroke_color: @parts_holes_stroke_color,
                                                        parts_holes_fill_color: @parts_holes_fill_color,
                                                        parts_paths_stroke_color: @parts_paths_stroke_color,
                                                        parts_paths_fill_color: @parts_paths_fill_color
              ).run
              return response if !response[:errors].nil? || response[:cancelled]
            when PART_DRAWING_TYPE_3D

              drawing_def = _compute_part_drawing_def(@part_drawing_type, part,
                                                      origin_position: @anchor ? CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
                                                      use_cache: false
              )
              return { :errors => [ 'tab.cutlist.error.unknow_part' ] } unless drawing_def.is_a?(DrawingDef)

              response = CommonWriteDrawing3dWorker.new(drawing_def,
                folder_path: folder_path,
                file_name: file_name,
                file_format: @file_format,
                unit: @unit,
                switch_yz: @switch_yz
              ).run
              return response if !response[:errors].nil? || response[:cancelled]
            end

          rescue => e
            puts e.inspect
            puts e.backtrace
            return { :errors => [ [ 'core.error.failed_export_to', { :path => folder_path, :error => e.message } ] ] }
          end

          end

        end

        { :export_path => dir }
      end

    end

  end

end