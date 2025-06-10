module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../lib/bin_packing_2d/packengine'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/string_utils'
  require_relative '../../model/geom/size2d'
  require_relative '../../model/cuttingdiagram/cuttingdiagram2d_def'

  class CutlistCuttingdiagram2dWorker

    include PartDrawingHelper
    include PixelConverterHelper

    ORIGIN_CORNER_TOP_LEFT = 0
    ORIGIN_CORNER_BOTTOM_LEFT = 1
    ORIGIN_CORNER_TOP_RIGHT = 2
    ORIGIN_CORNER_BOTTOM_RIGHT = 3

    def initialize(cutlist,

                   group_id: ,
                   part_ids: nil,
                   std_sheet: '',
                   scrap_sheet_sizes: '',
                   saw_kerf: '3mm',
                   trimming: '10mm',
                   optimization: BinPacking2D::OPT_MEDIUM,
                   stacking: BinPacking2D::STACKING_ALL,
                   keep_length: '100mm',
                   keep_width: '100mm',
                   sheet_folding: true,
                   hide_part_list: false,
                   part_drawing_type: PART_DRAWING_TYPE_NONE,
                   use_names: false,
                   full_width_diagram: false,
                   hide_cross: false,
                   origin_corner: ORIGIN_CORNER_TOP_LEFT,
                   highlight_primary_cuts: false,
                   hide_edges_preview: true

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids
      s_length, s_width = StringUtils.split_dxd(std_sheet)
      @std_sheet_length = DimensionUtils.str_to_ifloat(s_length).to_l.to_f
      @std_sheet_width = DimensionUtils.str_to_ifloat(s_width).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.dxdxq_to_ifloats(scrap_sheet_sizes)
      @saw_kerf = DimensionUtils.str_to_ifloat(saw_kerf).to_l.to_f
      @trimming = DimensionUtils.str_to_ifloat(trimming).to_l.to_f
      @optimization = optimization
      @stacking = stacking
      @keep_length = DimensionUtils.str_to_ifloat(keep_length).to_l.to_f
      @keep_width = DimensionUtils.str_to_ifloat(keep_width).to_l.to_f
      @sheet_folding = sheet_folding
      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type.to_i
      @use_names = use_names
      @full_width_diagram = full_width_diagram
      @hide_cross = hide_cross
      @origin_corner = origin_corner.to_i
      @highlight_primary_cuts = highlight_primary_cuts
      @hide_edges_preview = hide_edges_preview

      # Workaround to hide part drawing if group is edge decremented with out material oversize
      group = @cutlist.get_group(@group_id)
      if group && group.edge_decremented && (!group.material_length_increased || !group.material_width_increased)
        @part_drawing_type = PART_DRAWING_TYPE_NONE
      end

    end

    # -----

    def run(step_by_step = false)
      return Cuttingdiagram2dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram2d unless @cutlist

      model = Sketchup.active_model
      return Cuttingdiagram2dDef.new(nil, [ 'tab.cutlist.error.no_model' ]).create_cuttingdiagram2d unless model

      group = @cutlist.get_group(@group_id)
      return Cuttingdiagram2dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram2d unless group

      parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids)
      return Cuttingdiagram2dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram2d if parts.empty?

      unless @pack_engine

        # The dimensions need to be in Sketchup internal units AND float
        options = BinPacking2D::Options.new
        options.set_base_length(@std_sheet_length)
        options.set_base_width(@std_sheet_width)
        options.set_rotatable(!group.material_grained)
        options.set_saw_kerf(@saw_kerf)
        options.set_trimsize(@trimming)
        options.set_optimization(@optimization)
        options.set_stacking_pref(@stacking)
        # all leftovers smaller than either length or width will be marked with
        # the attribute @keep = true, part is larger in at least one dimension.
        options.set_keep(@keep_length, @keep_width)

        # Create the bin packing engine with given bins and boxes
        @pack_engine = BinPacking2D::PackEngine.new(options)

        # Add bins from scrap sheets
        @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
          ddq = scrap_sheet_size.split('x')
          length = ddq[0].strip.to_l.to_f
          width = ddq[1].strip.to_l.to_f
          quantity = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
          i = 0
          while i < quantity  do
            @pack_engine.add_bin(length, width)
            i += 1
          end
        }

        # Add boxes from parts
        fn_add_boxes = lambda { |part|
          for i in 1..part.count
            @pack_engine.add_box(part.cutting_length.to_l.to_f, part.cutting_width.to_l.to_f, options.rotatable || part.ignore_grain_direction, part.number, part)   # "to_l.to_f" Reconvert string representation of length to float to take advantage Sketchup precision
          end
        }
        parts.each { |part|
          if part.instance_of?(FolderPart)
            part.children.each { |child_part|
              fn_add_boxes.call(child_part)
            }
          else
            fn_add_boxes.call(part)
          end
        }

        # Start pack engine
        @pack_engine.start

        if step_by_step && !@pack_engine.errors?
          estimated_steps, signatures = @pack_engine.get_estimated_steps
          return { :estimated_steps => estimated_steps }
        end

      end
      until @pack_engine.done? || @pack_engine.errors?

        # Run pack engine
        @pack_engine.run

        # Break loop if step by step
        break if step_by_step

      end
      result = nil
      err = BinPacking2D::ERROR_NONE
      if @pack_engine.errors?
        err = @pack_engine.get_errors.first
      elsif @pack_engine.done?

        # Finish pack engine
        result, err = @pack_engine.finish

      end

      errors = []
      if err > BinPacking2D::ERROR_NONE

        # Engine error -> returns error only

        case err
          when BinPacking2D::ERROR_NO_BIN
            errors << 'tab.cutlist.cuttingdiagram.error.no_sheet'
          when BinPacking2D::ERROR_PARAMETERS
            errors << 'tab.cutlist.cuttingdiagram.error.parameters'
          when BinPacking2D::ERROR_NO_PLACEMENT_POSSIBLE
            errors << 'tab.cutlist.cuttingdiagram.error.no_placement_possible_2d'
          else # BinPacking2D::ERROR_BAD_ERROR and others
            errors << 'tab.cutlist.cuttingdiagram.error.bad_error'
        end

      end

      # Response
      # --------

      unless result
        return Cuttingdiagram2dDef.new(group, errors).create_cuttingdiagram2d
      end

      cuttingdiagram2d_def = Cuttingdiagram2dDef.new(group)
      cuttingdiagram2d_def.options_def.px_saw_kerf = [ _to_px(@saw_kerf), 1 ].max
      cuttingdiagram2d_def.options_def.saw_kerf = @saw_kerf
      cuttingdiagram2d_def.options_def.trimming = @trimming
      cuttingdiagram2d_def.options_def.optimization = @optimization
      cuttingdiagram2d_def.options_def.stacking = @stacking
      cuttingdiagram2d_def.options_def.keep_length = @keep_length
      cuttingdiagram2d_def.options_def.keep_width = @keep_width
      cuttingdiagram2d_def.options_def.sheet_folding = @sheet_folding
      cuttingdiagram2d_def.options_def.use_names = @use_names
      cuttingdiagram2d_def.options_def.hide_part_list = @hide_part_list
      cuttingdiagram2d_def.options_def.full_width_diagram = @full_width_diagram
      cuttingdiagram2d_def.options_def.hide_cross = @hide_cross
      cuttingdiagram2d_def.options_def.origin_corner = @origin_corner
      cuttingdiagram2d_def.options_def.highlight_primary_cuts = @highlight_primary_cuts
      cuttingdiagram2d_def.options_def.hide_edges_preview = @hide_edges_preview
      cuttingdiagram2d_def.options_def.part_drawing_type = @part_drawing_type

      cuttingdiagram2d_def.errors += errors

      # Errors
      if result.unplaced_boxes.length > 0
        cuttingdiagram2d_def.errors << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
      end

      # Warnings
      materials = Sketchup.active_model.materials
      material = materials[group.material_name]
      material_attributes = MaterialAttributes.new(material)
      if @part_ids
        cuttingdiagram2d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.is_part_selection'
      end
      if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
        cuttingdiagram2d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
      end
      if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
        cuttingdiagram2d_def.warnings << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_2d', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
      end
      if group.edge_decremented
        cuttingdiagram2d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_edge_decrement'
      end

      # Material oversizes
      part_x_offset = material_attributes.l_length_increase / 2
      part_y_offset = material_attributes.l_width_increase / 2

      # Unplaced boxes
      result.unplaced_boxes.each { |box|
        part_def = cuttingdiagram2d_def.unplaced_part_defs[box.data.number]
        unless part_def
          part_def = Cuttingdiagram2dListedPartDef.new(box.data)
          cuttingdiagram2d_def.unplaced_part_defs[box.data.number] = part_def
        end
        part_def.count += 1
      }

      # Summary
      cuttingdiagram2d_def.summary_def.overall_efficiency = result.overall_efficiency
      result.unused_bins.each { |bin|
        _append_bin_to_summary_sheet_defs(bin, group, false, cuttingdiagram2d_def.summary_def.sheet_defs)
      }
      result.packed_bins.each { |bin|
        _append_bin_to_summary_sheet_defs(bin, group, true, cuttingdiagram2d_def.summary_def.sheet_defs)
        cuttingdiagram2d_def.summary_def.total_used_count += 1
        cuttingdiagram2d_def.summary_def.total_used_area += Size2d.new(bin.length.to_l, bin.width.to_l).area
        cuttingdiagram2d_def.summary_def.total_used_part_count += bin.boxes.count
        bin.cuts.each { |cut|
          cuttingdiagram2d_def.summary_def.total_cut_count += 1
          cuttingdiagram2d_def.summary_def.total_cut_length += cut.length
        }
      }

      # Sheets
      sheet_key = 0
      result.packed_bins.each { |bin|

        type_id = _compute_bin_type_id(bin, group, true)
        sheet_key = @sheet_folding ? "#{type_id}|#{bin.boxes.map { |box| box.data.number }.join('|')}" : (sheet_key += 1)

        # Check similarity
        if @sheet_folding
          grouped_sheet_def = cuttingdiagram2d_def.sheet_defs[sheet_key]
          if grouped_sheet_def
            grouped_sheet_def.count += 1
            next
          end
        end

        sheet_def = Cuttingdiagram2dSheetDef.new
        sheet_def.type_id = type_id
        sheet_def.type = bin.type
        sheet_def.count = 1
        sheet_def.px_length = _to_px(bin.length)
        sheet_def.px_width = _to_px(bin.width)
        sheet_def.length = bin.length
        sheet_def.width = bin.width
        sheet_def.efficiency = bin.efficiency
        sheet_def.total_cut_length = bin.total_length_cuts

        # Parts
        bin.boxes.each { |box|

          part_def = Cuttingdiagram2dPartDef.new(box.data)
          part_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, box.x_pos, box.length, bin.length))
          part_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, box.y_pos, box.width, bin.width))
          part_def.px_x_offset = _to_px(box.rotated ? part_y_offset : part_x_offset)
          part_def.px_y_offset = _to_px(box.rotated ? part_x_offset : part_y_offset)
          part_def.px_length = _to_px(box.length)
          part_def.px_width = _to_px(box.width)
          part_def.rotated = box.rotated
          sheet_def.part_defs.push(part_def)

          unless @hide_part_list
            grouped_part_def = sheet_def.grouped_part_defs[box.data.id]
            unless grouped_part_def

              grouped_part_def = Cuttingdiagram2dListedPartDef.new(box.data)
              sheet_def.grouped_part_defs[box.data.id] = grouped_part_def

            end
            grouped_part_def.count += 1
          end

          # Part is used : compute its projection if enabled
          _compute_part_projection_def(@part_drawing_type, box.data) unless @part_drawing_type == PART_DRAWING_TYPE_NONE

        }

        # Leftovers
        bin.leftovers.each { |leftover|

          leftover_def = Cuttingdiagram2dLeftoverDef.new
          leftover_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, leftover.x_pos, leftover.length, bin.length))
          leftover_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, leftover.y_pos, leftover.width, bin.width))
          leftover_def.px_length = _to_px(leftover.length)
          leftover_def.px_width = _to_px(leftover.width)
          leftover_def.length = leftover.length
          leftover_def.width = leftover.width
          leftover_def.to_keep = leftover.keep
          sheet_def.leftover_defs.push(leftover_def)

          if leftover.keep

            leftover_key = "#{leftover.length}x#{leftover.width}"
            to_keep_leftover_def = cuttingdiagram2d_def.to_keep_leftover_defs[leftover_key]
            if to_keep_leftover_def.nil?

              to_keep_leftover_def = Cuttingdiagram2dListedLeftoverDef.new
              to_keep_leftover_def.sheet_def = sheet_def
              to_keep_leftover_def.leftover_def = leftover_def
              cuttingdiagram2d_def.to_keep_leftover_defs[leftover_key] = to_keep_leftover_def

            end
            to_keep_leftover_def.count += 1

          end

        }

        # Cuts
        bin.cuts.each { |cut|

          cut_def = Cuttingdiagram2dCutDef.new
          cut_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, cut.x_pos, cut.is_horizontal ? cut.length : @saw_kerf, bin.length))
          cut_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, cut.y_pos, cut.is_horizontal ? @saw_kerf : cut.length, bin.width))
          cut_def.px_length = _to_px(cut.length)
          cut_def.x = cut.x_pos
          cut_def.y = cut.y_pos
          cut_def.length = cut.length
          cut_def.is_horizontal = cut.is_horizontal
          cut_def.is_trimming = cut.cut_type == BinPacking2D::TRIMMING_CUT
          cut_def.is_bounding = cut.cut_type == BinPacking2D::BOUNDING_CUT
          cut_def.is_internal_through = cut.cut_type == BinPacking2D::INTERNAL_THROUGH_CUT
          sheet_def.cut_defs.push(cut_def)

        }

        cuttingdiagram2d_def.sheet_defs[sheet_key] = sheet_def

      }

      cuttingdiagram2d_def.create_cuttingdiagram2d
    end

    # -----

    private

    def _compute_bin_type_id(bin, group, used)
      Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{bin.width.to_l.to_s}_#{bin.type}_#{used ? 1 : 0}")
    end

    def _append_bin_to_summary_sheet_defs(bin, group, used, summary_sheet_defs)
      type_id = _compute_bin_type_id(bin, group, used)
      sheet_def = summary_sheet_defs[type_id]
      unless sheet_def

        sheet_def = Cuttingdiagram2dSummarySheetDef.new
        sheet_def.type_id = type_id
        sheet_def.type = bin.type
        sheet_def.length = bin.length
        sheet_def.width = bin.width
        sheet_def.is_used = used

        summary_sheet_defs[type_id] = sheet_def
      end
      sheet_def.count += 1
      sheet_def.total_area += Size2d.new(bin.length.to_l, bin.width.to_l).area
      sheet_def.total_part_count += bin.boxes.count
    end

    def _compute_x_with_origin_corner(origin_corner, x, x_size, x_translation)
      case origin_corner
        when ORIGIN_CORNER_TOP_RIGHT, ORIGIN_CORNER_BOTTOM_RIGHT
          x_translation - x - x_size
        else
          x
      end
    end

    def _compute_y_with_origin_corner(origin_corner, y, y_size, y_translation)
      case origin_corner
        when ORIGIN_CORNER_BOTTOM_LEFT, ORIGIN_CORNER_BOTTOM_RIGHT
          y_translation - y - y_size
        else
          y
      end
    end

  end

end
