module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_1d/packengine'
  require_relative '../../utils/dimension_utils'
  require_relative '../../model/cuttingdiagram/cuttingdiagram_1d_def'

  class CutlistCuttingdiagram1dWorker

    ORIGIN_CORNER_LEFT = 0
    ORIGIN_CORNER_RIGHT = 1

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @part_ids = settings['part_ids']
      @std_bar_length = DimensionUtils.instance.str_to_ifloat(settings['std_bar']).to_l.to_f
      @scrap_bar_lengths = DimensionUtils.instance.dxq_to_ifloats(settings['scrap_bar_lengths'])
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @bar_folding = settings['bar_folding']
      @hide_part_list = settings['hide_part_list']
      @full_width_diagram = settings['full_width_diagram']
      @hide_cross = settings['hide_cross']
      @origin_corner = settings['origin_corner']
      @wrap_length = DimensionUtils.instance.str_to_ifloat(settings['wrap_length']).to_l.to_f

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
      options = BinPacking1D::Options.new(@std_bar_length, @saw_kerf, @trimming)

      # Create the bin packing engine with given bins and boxes
      e = BinPacking1D::PackEngine.new(options)

      # Add bins from scrap lengths
      @scrap_bar_lengths.split(';').each { |scrap_bar_length|
        dq = scrap_bar_length.split('x')
        length = dq[0].strip.to_l.to_f
        quantity = [ 1, (dq[1].nil? || dq[1].strip.to_i == 0) ? 1 : dq[1].strip.to_i ].max
        i = 0
        while i < quantity  do
          e.add_bin(length)
          i += 1
        end
      }

      # Add boxes from parts
      parts.each { |part|
        for i in 1..part.count
          e.add_box(part.cutting_length.to_l.to_f, part)   # "to_l.to_f" Reconvert string représentation of length to float to take advantage Sketchup precision
        end
      }

      # Compute the cutting diagram
      result, err = e.run

      # Response
      # --------

      cuttingdiagram1d_def = Cuttingdiagram1dDef.new
      cuttingdiagram1d_def.options_def.px_saw_kerf = [_to_px(@saw_kerf), 1].max
      cuttingdiagram1d_def.options_def.saw_kerf = @saw_kerf
      cuttingdiagram1d_def.options_def.trimming = @trimming
      cuttingdiagram1d_def.options_def.bar_folding = @bar_folding
      cuttingdiagram1d_def.options_def.hide_part_list = @hide_part_list
      cuttingdiagram1d_def.options_def.full_width_diagram = @full_width_diagram
      cuttingdiagram1d_def.options_def.hide_cross = @hide_cross
      cuttingdiagram1d_def.options_def.origin_corner = @origin_corner
      cuttingdiagram1d_def.options_def.wrap_length = @wrap_length

      if err > BinPacking1D::ERROR_SUBOPT

        # Engine error -> returns error only

        case err
        when BinPacking1D::ERROR_NO_BIN
          cuttingdiagram1d_def.errors << 'tab.cutlist.cuttingdiagram.error.no_bar'
        when BinPacking1D::ERROR_PARAMETERS
          cuttingdiagram1d_def.errors << 'tab.cutlist.cuttingdiagram.error.parameters'
        when BinPacking1D::ERROR_NO_BOX
          cuttingdiagram1d_def.errors << 'tab.cutlist.cuttingdiagram.error.no_parts'
        when BinPacking1D::ERROR_BAD_ERROR
          cuttingdiagram1d_def.errors << 'tab.cutlist.cuttingdiagram.error.bad_error'
        else
          puts('funky error, contact developpers', err)
        end
        
      else

        # Errors
        if result.unplaced_boxes.length > 0
          cuttingdiagram1d_def.errors << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
        end
        
        # Warnings
        materials = Sketchup.active_model.materials
        material = materials[group.material_name]
        material_attributes = MaterialAttributes.new(material)
        if @part_ids
          cuttingdiagram1d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.selection_only'
        end
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
          cuttingdiagram1d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
        end
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
          cuttingdiagram1d_def.warnings << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_1d', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
        end

        # Unplaced boxes
        result.unplaced_boxes.each { |box|
          part_def = cuttingdiagram1d_def.unplaced_part_defs[box.data.number]
          unless part_def
            part_def = Cuttingdiagram1dListedPartDef.new(box.data)
            cuttingdiagram1d_def.unplaced_part_defs[box.data.number] = part_def
          end
          part_def.count += 1
        }

        # Summary
        result.unused_bins.each { |bin|
          _append_bin_to_summary_bars(bin, group, false, cuttingdiagram1d_def.summary_def.bar_defs)
        }
        result.bins.each { |bin|
          _append_bin_to_summary_bars(bin, group, true, cuttingdiagram1d_def.summary_def.bar_defs)
          cuttingdiagram1d_def.summary_def.total_used_count += 1
          cuttingdiagram1d_def.summary_def.total_used_length += bin.length
          cuttingdiagram1d_def.summary_def.total_used_part_count += bin.boxes.count
        }

        # Bars
        bar_key = 0
        result.bins.each { |bin|

          type_id = _compute_bin_type_id(bin, group, true)
          bar_key = @bar_folding ? "#{type_id}|#{bin.boxes.map { |box| box.data.number }.join('|')}" : (bar_key += 1)

          # Check similarity
          if @bar_folding
            bar_def = cuttingdiagram1d_def.bar_defs[bar_key]
            if bar_def
              bar_def.count += 1
              next
            end
          end

          wrap_length = [ @wrap_length, bin.length ].min
          wrap_length = bin.length if wrap_length <= @trimming + @saw_kerf

          bar_def = Cuttingdiagram1dBarDef.new
          bar_def.type_id = type_id
          bar_def.type = bin.type
          bar_def.count = 1
          bar_def.px_length = _to_px(bin.length)
          bar_def.px_width = _to_px(group.def.std_width)
          bar_def.length = bin.length
          bar_def.width = group.def.std_width
          bar_def.efficiency = bin.efficiency

          slice_count = (bin.length / wrap_length).ceil
          i = 0
          while i < slice_count do
            slice_length = [ wrap_length, bin.length - i * wrap_length ].min
            slice_def = Cuttingdiagram1dSliceDef.new
            slice_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, 0, slice_length, wrap_length))
            slice_def.px_length = _to_px(slice_length)
            bar_def.slice_defs.push(slice_def)
            i += 1
          end

          # Parts
          bin.boxes.each { |box|

            part_def = Cuttingdiagram1dPartDef.new(box.data)
            part_def.slice_defs.concat(_to_slice_defs(box.x, box.length, wrap_length))
            bar_def.part_defs.push(part_def)

            unless @hide_part_list
              grouped_part_def = bar_def.grouped_part_defs[box.data.id]
              unless grouped_part_def
                grouped_part_def = Cuttingdiagram1dListedPartDef.new(box.data)
                bar_def.grouped_part_defs[box.data.id] = grouped_part_def
              end
              grouped_part_def.count += 1
            end
          }

          # Leftover
          lefover_def = Cuttingdiagram1dLeftoverDef.new
          lefover_def.x = bin.current_position
          lefover_def.length = bin.current_leftover
          lefover_def.slice_defs.concat(_to_slice_defs(bin.current_position, bin.current_leftover, wrap_length))
          bar_def.leftover_def = lefover_def

          # Cuts
          bin.cuts.each { |cut|
            cut_def = Cuttingdiagram1dCutDef.new
            cut_def.x = cut.to_l
            cut_def.slice_defs.concat(_to_slice_defs(cut, @saw_kerf, wrap_length))
            bar_def.cut_defs.push(cut_def)
          }

          cuttingdiagram1d_def.bar_defs[bar_key] = bar_def

        }

      end

      cuttingdiagram1d_def.create_cuttingdiagram1d
    end

    # -----

    private

    def _compute_bin_type_id(bin, group, used)
      Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{group.def.std_width.to_s}_#{bin.type}_#{used ? 1 : 0}")
    end

    def _append_bin_to_summary_bars(bin, group, used, summary_bar_defs)
      type_id = _compute_bin_type_id(bin, group, used)
      bar_def = summary_bar_defs[type_id]
      unless bar_def

        bar_def = Cuttingdiagram1dSummaryBarDef.new
        bar_def.type_id = type_id
        bar_def.type = bin.type
        bar_def.length = bin.length
        bar_def.is_used = used

        summary_bar_defs[type_id] = bar_def
      end
      bar_def.count += 1
      bar_def.total_length += bin.length
      bar_def.total_part_count += bin.boxes.count
    end

    def _compute_x_with_origin_corner(origin_corner, x, x_size, x_translation)
      case origin_corner
      when ORIGIN_CORNER_RIGHT
        x_translation - x - x_size
      else
        x
      end
    end

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value * 7 # 840px = 120" ~ 3m
    end

    # Convert inch float value to slice index
    def _to_slice_index(inch_value, wrap_length)
      wrap_length == 0 ? 0 : (inch_value / wrap_length).floor
    end

    def _to_slice_defs(x, length, wrap_length)

      start_slice_index = _to_slice_index(x, wrap_length)
      end_slice_index = _to_slice_index(x + length, wrap_length)

      slice_defs = []
      slice_index = start_slice_index
      current_x = x
      remaining_length = length
      while slice_index <= end_slice_index do

        bar_slice_x = wrap_length * slice_index
        part_slice_x = current_x - bar_slice_x
        part_slice_length = [wrap_length - part_slice_x, remaining_length ].min

        slice_def = Cuttingdiagram1dSliceDef.new
        slice_def.index = slice_index
        slice_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, part_slice_x, part_slice_length, wrap_length))
        slice_def.px_length = _to_px(part_slice_length)
        slice_defs.push(slice_def)

        slice_index += 1
        current_x += part_slice_length
        remaining_length -= part_slice_length

      end

      slice_defs
    end

  end

end