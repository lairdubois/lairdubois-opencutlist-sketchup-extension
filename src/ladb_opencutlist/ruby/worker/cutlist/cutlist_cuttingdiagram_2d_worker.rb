module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_2d/packengine'
  require_relative '../../model/geom/size2d'
  require_relative '../../utils/dimension_utils'
  require_relative '../../model/cuttingdiagram/cuttingdiagram_2d_def'

  class CutlistCuttingdiagram2dWorker

    ORIGIN_CORNER_TOP_LEFT = 0
    ORIGIN_CORNER_BOTTOM_LEFT = 1
    ORIGIN_CORNER_TOP_RIGHT = 2
    ORIGIN_CORNER_BOTTOM_RIGHT = 3

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @part_ids = settings['part_ids']
      s_length, s_width = StringUtils.split_dxd(settings['std_sheet'])
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(s_length).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(s_width).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxdxq_to_ifloats(settings['scrap_sheet_sizes'])
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @optimization = settings['optimization']
      @stacking = settings['stacking']
      @sheet_folding = settings['sheet_folding']
      @full_width_diagram = settings['full_width_diagram']
      @hide_part_list = settings['hide_part_list']
      @hide_cross = settings['hide_cross']
      @origin_corner = settings['origin_corner']
      @highlight_primary_cuts = settings['highlight_primary_cuts']

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      group = @cutlist.get_group(@group_id)
      return { :errors => [ 'default.error' ] } unless group

      parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids)
      return { :errors => [ 'default.error' ] } if parts.empty?

      # The dimensions need to be in Sketchup internal units AND float
      options = BinPacking2D::Options.new
      options.set_base_length(@std_sheet_length)
      options.set_base_width(@std_sheet_width)
      options.set_rotatable(!group.material_grained)
      options.set_saw_kerf(@saw_kerf)
      options.set_trimsize(@trimming)
      options.set_optimization(@optimization)
      options.set_stacking_pref(@stacking)

      # Create the bin packing engine with given bins and boxes
      e = BinPacking2D::PackEngine.new(options)

      # Add bins from scrap sheets
      @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
        ddq = scrap_sheet_size.split('x')
        length = ddq[0].strip.to_l.to_f
        width = ddq[1].strip.to_l.to_f
        quantity = [ 1, (ddq[2].nil? || ddq[2].strip.to_i == 0) ? 1 : ddq[2].strip.to_i ].max
        i = 0
        while i < quantity  do
          e.add_bin(length, width)
          i += 1
        end
      }

      # Add boxes from parts
      # TODO possible future, single parts can be made non-rotatable, for now
      # they inherit the attribute from options
      parts.each { |part|
        for i in 1..part.count
          e.add_box(part.cutting_length.to_l.to_f, part.cutting_width.to_l.to_f, options.rotatable, part)   # "to_l.to_f" Reconvert string representation of length to float to take advantage Sketchup precision
        end
      }

      # Compute the cutting diagram
      result, err = e.run

      # Response
      # --------

      cuttingdiagram2d_def = Cuttingdiagram2dDef.new
      cuttingdiagram2d_def.options_def.px_saw_kerf = [_to_px(@saw_kerf), 1].max
      cuttingdiagram2d_def.options_def.saw_kerf = @saw_kerf
      cuttingdiagram2d_def.options_def.trimming = @trimming
      cuttingdiagram2d_def.options_def.optimization = @optimization
      cuttingdiagram2d_def.options_def.stacking = @stacking
      cuttingdiagram2d_def.options_def.sheet_folding = @sheet_folding
      cuttingdiagram2d_def.options_def.hide_part_list = @hide_part_list
      cuttingdiagram2d_def.options_def.full_width_diagram = @full_width_diagram
      cuttingdiagram2d_def.options_def.hide_cross = @hide_cross
      cuttingdiagram2d_def.options_def.origin_corner = @origin_corner
      cuttingdiagram2d_def.options_def.highlight_primary_cuts = @highlight_primary_cuts

      if err > BinPacking2D::ERROR_NONE

        # Engine error -> returns error only

        case err
          when BinPacking2D::ERROR_NO_BIN
            cuttingdiagram2d_def.errors << 'tab.cutlist.cuttingdiagram.error.no_sheet'
          when BinPacking2D::ERROR_NO_PLACEMENT_POSSIBLE
            cuttingdiagram2d_def.errors << 'tab.cutlist.cuttingdiagram.error.no_placement_possible'
          when BinPacking2D::ERROR_BAD_ERROR
            cuttingdiagram2d_def.errors << 'tab.cutlist.cuttingdiagram.error.bad_error'
        end

      else

        # Errors
        if result.unplaced_boxes.length > 0
          cuttingdiagram2d_def.errors << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
        end

        # Warnings
        materials = Sketchup.active_model.materials
        material = materials[group.material_name]
        material_attributes = MaterialAttributes.new(material)
        if @part_ids
          cuttingdiagram2d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.selection_only'
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
        result.unused_bins.each { |bin|
          _append_bin_to_summary_sheet_defs(bin, group, false, cuttingdiagram2d_def.summary_def.sheet_defs)
        }
        result.packed_bins.each { |bin|
          _append_bin_to_summary_sheet_defs(bin, group, true, cuttingdiagram2d_def.summary_def.sheet_defs)
          cuttingdiagram2d_def.summary_def.total_used_count += 1
          cuttingdiagram2d_def.summary_def.total_used_area += Size2d.new(bin.length.to_l, bin.width.to_l).area
          cuttingdiagram2d_def.summary_def.total_used_part_count += bin.boxes.count
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
          sheet_def.total_length_cuts = bin.total_length_cuts

          # Parts
          bin.boxes.each { |box|

            part_def = Cuttingdiagram2dPartDef.new(box.data)
            part_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, box.x, box.length, bin.length))
            part_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, box.y, box.width, bin.width))
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
          }

          # Leftovers
          bin.leftovers.each { |box|

            leftover_def = Cuttingdiagram2dLeftoverDef.new
            leftover_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, box.x, box.length, bin.length))
            leftover_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, box.y, box.width, bin.width))
            leftover_def.px_length = _to_px(box.length)
            leftover_def.px_width = _to_px(box.width)
            leftover_def.length = box.length
            leftover_def.width = box.width
            sheet_def.leftover_defs.push(leftover_def)

          }

          # Cuts
          bin.cuts.each { |cut|

            cut_def = Cuttingdiagram2dCutDef.new
            cut_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, cut.x, cut.is_horizontal ? cut.length : 0, bin.length))
            cut_def.px_y = _to_px(_compute_y_with_origin_corner(@origin_corner, cut.y, cut.is_horizontal ? 0 : cut.length, bin.width))
            cut_def.px_length = _to_px(cut.length)
            cut_def.x = cut.x
            cut_def.y = cut.y
            cut_def.length = cut.length
            cut_def.is_horizontal = cut.is_horizontal
            cut_def.is_through = cut.is_through
            cut_def.is_final = cut.is_final
            sheet_def.cut_defs.push(cut_def)

          }

          cuttingdiagram2d_def.sheet_defs[sheet_key] = sheet_def

        }

      end

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

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value * 7 # 840px = 120" ~ 3m
    end

  end

end
