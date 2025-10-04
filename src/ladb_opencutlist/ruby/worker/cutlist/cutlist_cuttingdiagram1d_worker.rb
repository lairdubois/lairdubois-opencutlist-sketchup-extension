module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../helper/pixel_converter_helper'
  require_relative '../../lib/bin_packing_1d/packengine'
  require_relative '../../utils/dimension_utils'
  require_relative '../../model/cuttingdiagram/cuttingdiagram1d_def'

  class CutlistCuttingdiagram1dWorker

    include PartDrawingHelper
    include PixelConverterHelper

    ORIGIN_CORNER_LEFT = 0
    ORIGIN_CORNER_RIGHT = 1

    def initialize(cutlist,

                   group_id: ,
                   part_ids: nil,
                   std_bar: '',
                   scrap_bar_lengths: '',
                   saw_kerf: '3mm',
                   trimming: '20mm',
                   bar_folding: true,
                   hide_part_list: false,
                   part_drawing_type: PART_DRAWING_TYPE_NONE,
                   use_names: false,
                   full_width_diagram: false,
                   hide_cross: false,
                   origin_corner: ORIGIN_CORNER_LEFT,
                   wrap_length: '3000mm'

    )

      @cutlist = cutlist

      @group_id = group_id
      @part_ids = part_ids
      @std_bar_length = DimensionUtils.str_to_ifloat(std_bar).to_l.to_f
      @scrap_bar_lengths = DimensionUtils.dxq_to_ifloats(scrap_bar_lengths)
      @saw_kerf = DimensionUtils.str_to_ifloat(saw_kerf).to_l.to_f
      @trimming = DimensionUtils.str_to_ifloat(trimming).to_l.to_f
      @bar_folding = bar_folding
      @hide_part_list = hide_part_list
      @part_drawing_type = part_drawing_type.to_i
      @use_names = use_names
      @full_width_diagram = full_width_diagram
      @hide_cross = hide_cross
      @origin_corner = origin_corner
      @wrap_length = DimensionUtils.str_to_ifloat(wrap_length).to_l.to_f

    end

    # -----

    def run(step_by_step = false)
      return Cuttingdiagram1dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram1d unless @cutlist

      model = Sketchup.active_model
      return Cuttingdiagram1dDef.new(nil, [ 'tab.cutlist.error.no_model' ]).create_cuttingdiagram1d unless model

      group = @cutlist.get_group(@group_id)
      return Cuttingdiagram1dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram1d unless group

      parts = @part_ids.nil? ? group.parts : group.get_parts(@part_ids, real: false)
      return Cuttingdiagram1dDef.new(nil, [ 'default.error' ]).create_cuttingdiagram1d if parts.empty?

      _set_pixel_to_inch_factor(7)

      unless @pack_engine

        # The dimensions need to be in Sketchup internal units AND float
        options = BinPacking1D::Options.new(@std_bar_length, @saw_kerf, @trimming)

        # Create the bin packing engine with given bins and boxes
        @pack_engine = BinPacking1D::PackEngine.new(options)

        # Add bins from scrap lengths
        @scrap_bar_lengths.split(';').each { |scrap_bar_length|
          dq = scrap_bar_length.split('x')
          length = dq[0].strip.to_l.to_f
          quantity = [ 1, (dq[1].nil? || dq[1].strip.to_i == 0) ? 1 : dq[1].strip.to_i ].max
          i = 0
          while i < quantity  do
            @pack_engine.add_bin(length)
            i += 1
          end
        }

        # Add boxes from parts
        fn_add_boxes = lambda { |part|
          for i in 1..part.count
            @pack_engine.add_box(part.cutting_length.to_l.to_f, part.number, part)   # "to_l.to_f" Reconvert string représentation of length to float to take advantage Sketchup precision
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
      err = BinPacking1D::ERROR_NONE
      if @pack_engine.errors?
        err = @pack_engine.get_errors.first
      elsif @pack_engine.done?

        # Finish pack engine
        result, err = @pack_engine.finish

      end

      errors = []
      if err > BinPacking1D::ERROR_NONE

        # Engine error -> returns error only

        case err
        when BinPacking1D::ERROR_NO_BIN
          errors << 'tab.cutlist.cuttingdiagram.error.no_bar_' + (group.material_type == MaterialAttributes::TYPE_EDGE ? 'edge' : 'dimensional')
        when BinPacking1D::ERROR_PARAMETERS
          errors << 'tab.cutlist.cuttingdiagram.error.parameters'
        when BinPacking1D::ERROR_NO_PLACEMENT_POSSIBLE
          errors << 'tab.cutlist.cuttingdiagram.error.no_placement_possible_1d'
        else # BinPacking1D::ERROR_BAD_ERROR and others
          errors << 'tab.cutlist.cuttingdiagram.error.bad_error'
        end

      end

      # Response
      # --------

      unless result
        return Cuttingdiagram1dDef.new(group, errors).create_cuttingdiagram1d
      end

      cuttingdiagram1d_def = Cuttingdiagram1dDef.new(group)
      cuttingdiagram1d_def.options_def.px_saw_kerf = [ _to_px(@saw_kerf), 1 ].max
      cuttingdiagram1d_def.options_def.saw_kerf = @saw_kerf
      cuttingdiagram1d_def.options_def.trimming = @trimming
      cuttingdiagram1d_def.options_def.bar_folding = @bar_folding
      cuttingdiagram1d_def.options_def.hide_part_list = @hide_part_list
      cuttingdiagram1d_def.options_def.use_names = @use_names
      cuttingdiagram1d_def.options_def.full_width_diagram = @full_width_diagram
      cuttingdiagram1d_def.options_def.hide_cross = @hide_cross
      cuttingdiagram1d_def.options_def.origin_corner = @origin_corner
      cuttingdiagram1d_def.options_def.wrap_length = @wrap_length
      cuttingdiagram1d_def.options_def.part_drawing_type = @part_drawing_type

      cuttingdiagram1d_def.errors += errors

      # Errors
      if result.unplaced_boxes.length > 0
        cuttingdiagram1d_def.errors << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
      end

      # Warnings
      materials = Sketchup.active_model.materials
      material = materials[group.material_name]
      material_attributes = MaterialAttributes.new(material)
      if @part_ids
        cuttingdiagram1d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.is_part_selection'
      end
      if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
        cuttingdiagram1d_def.warnings << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
      end
      if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
        cuttingdiagram1d_def.warnings << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_1d', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
      end

      # Material oversizes
      part_x_offset = material_attributes.l_length_increase / 2

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
      cuttingdiagram1d_def.summary_def.overall_efficiency = result.overall_efficiency
      result.unused_bins.each { |bin|
        _append_bin_to_summary_bars(bin, group, false, cuttingdiagram1d_def.summary_def.bar_defs)
      }
      result.bins.each { |bin|
        _append_bin_to_summary_bars(bin, group, true, cuttingdiagram1d_def.summary_def.bar_defs)
        cuttingdiagram1d_def.summary_def.total_used_count += 1
        cuttingdiagram1d_def.summary_def.total_used_length += bin.length
        cuttingdiagram1d_def.summary_def.total_used_part_count += bin.boxes.count
        bin.cuts.each { |cut|
          cuttingdiagram1d_def.summary_def.total_cut_count += 1
          cuttingdiagram1d_def.summary_def.total_cut_length += group.def.std_width
        }
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
        bin.cuts.each { |cut|
          bar_def.total_cut_length += group.def.std_width
        }

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
          part_def.px_x = _to_px(_compute_x_with_origin_corner(@origin_corner, box.x_pos, box.length, bin.length))
          part_def.px_x_offset = _to_px(part_x_offset)
          part_def.px_length = _to_px(box.length)
          part_def.slice_defs.concat(_to_slice_defs(box.x_pos, box.length, wrap_length))
          bar_def.part_defs.push(part_def)

          unless @hide_part_list
            grouped_part_def = bar_def.grouped_part_defs[box.data.id]
            unless grouped_part_def
              grouped_part_def = Cuttingdiagram1dListedPartDef.new(box.data)
              bar_def.grouped_part_defs[box.data.id] = grouped_part_def
            end
            grouped_part_def.count += 1
          end

          # Part is used : compute its projection if enabled
          _compute_part_projection_def(@part_drawing_type, box.data) unless @part_drawing_type == PART_DRAWING_TYPE_NONE

        }

        # Leftover
        lefover_def = Cuttingdiagram1dLeftoverDef.new
        lefover_def.px_x = _to_px(bin.current_position)
        lefover_def.px_length = _to_px(bin.current_leftover)
        lefover_def.length = bin.current_leftover
        lefover_def.slice_defs.concat(_to_slice_defs(bin.current_position, bin.current_leftover, wrap_length))
        bar_def.leftover_def = lefover_def

        # Cuts
        bin.cuts.each { |cut|
          cut_def = Cuttingdiagram1dCutDef.new
          cut_def.px_x = _to_px(cut.to_l)
          cut_def.x = cut.to_l
          cut_def.slice_defs.concat(_to_slice_defs(cut, @saw_kerf, wrap_length))
          bar_def.cut_defs.push(cut_def)
        }

        cuttingdiagram1d_def.bar_defs[bar_key] = bar_def

      }

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
