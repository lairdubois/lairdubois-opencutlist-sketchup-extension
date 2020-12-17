module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_2d/packengine'
  require_relative '../../model/geom/size2d'
  require_relative '../../utils/dimension_utils'

  class CutlistCuttingdiagram2dWorker

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @part_ids = settings['part_ids']
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_length']).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_width']).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxdxq_to_ifloats(settings['scrap_sheet_sizes'])
      @grained = settings['grained']
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      # TODO presort, bbox is gone
      #@presort = BinPacking2D::Packing2D.valid_presort(settings['presort'])
      #@stacking = BinPacking2D::Packing2D.valid_stacking(settings['stacking'])
      @optimization = settings['optimization'].to_i
      @stacking = settings['stacking'].to_i
      #@bbox_optimization = BinPacking2D::Packing2D.valid_bbox_optimization(settings['bbox_optimization'])
      @sheet_folding = settings['sheet_folding']
      @hide_part_list = settings['hide_part_list']

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
      # TODO changed name
      options.base_length = @std_sheet_length
      options.base_width = @std_sheet_width
      options.rotatable = !@grained
      options.saw_kerf = @saw_kerf
      # TODO changed name
      options.trimsize = @trimming
      options.optimization = @optimization
      options.stacking_pref = @stacking
      # TODO gone
      #options.bbox_optimization = @bbox_optimization
      #options.presort = @presort

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
      # TODO future possible, single parts can be made non-rotatable, for now
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

      response = {
          :errors => [],
          :warnings => [],
          :tips => [],

          :options => {
              :grained => @grained,
              :sheet_folding => @sheet_folding,
              :hide_part_list => @hide_part_list,
              :px_saw_kerf => _to_px(options.saw_kerf),
              :saw_kerf => options.saw_kerf.to_l.to_s,
              # TODO changed name
              :trimming => options.trimsize.to_l.to_s,
              :optimization => @optimization,
              :stacking => @stacking,
              # TODO removed
              #:bbox_optimization => @bbox_optimization,
              #:presort => @presort,
          },

          :unplaced_parts => [],
          :summary => {
              :sheets => [],
              :total_used_count => 0,
              :total_used_area => 0,
          },
          :sheets => [],
      }

      if err > BinPacking2D::ERROR_NONE

        # Engine error -> returns error only

        case err
          when BinPacking2D::ERROR_NO_BIN
            response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_sheet'
          when BinPacking2D::ERROR_NO_PLACEMENT_POSSIBLE
            response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_placement_possible'
          when BinPacking2D::ERROR_BAD_ERROR
            response[:errors] << 'tab.cutlist.cuttingdiagram.error.bad_error'
        end

      else

        # Errors
        if result.unplaced_boxes.length > 0
          response[:errors] << [ 'tab.cutlist.cuttingdiagram.error.unplaced_parts', { :count => result.unplaced_boxes.length } ]
        end

        # Warnings
        materials = Sketchup.active_model.materials
        material = materials[group.material_name]
        material_attributes = MaterialAttributes.new(material)
        if @part_ids
          response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.selection_only'
        end
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
          response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
        end
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
          response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_2d', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
        end
        if group.edge_decremented
          response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_edge_decrement'
        end

        # Unplaced boxes
        unplaced_parts = {}
        result.unplaced_boxes.each { |box|
          part = unplaced_parts[box.data.number]
          unless part
            part = {
                :id => box.data.id,
                :number => box.data.number,
                :name => box.data.name,
                :length => box.data.length,
                :width => box.data.width,
                :cutting_length => box.data.cutting_length,
                :cutting_width => box.data.cutting_width,
                :edge_count => box.data.edge_count,
                :edge_pattern => box.data.edge_pattern,
                :edge_decrements => box.data.edge_decrements,
                :count => 0,
            }
            unplaced_parts[box.data.number] = part
          end
          part[:count] += 1
        }
        unplaced_parts.sort_by { |k, v| v[:number] }.each { |key, part|
          response[:unplaced_parts].push(part)
        }

        # Summary
        summary_sheets = {}
        result.unused_bins.each { |bin|
          _append_bin_to_summary_sheets(bin, group, false, summary_sheets)
        }
        # TODO moved to packed bin
        result.packed_bins.each { |bin|
          _append_bin_to_summary_sheets(bin, group, true, summary_sheets)
          response[:summary][:total_used_count] += 1
          response[:summary][:total_used_area] += Size2d.new(bin.length.to_l, bin.width.to_l).area
        }
        summary_sheets.each { |type_id, sheet|
          sheet[:total_area] = DimensionUtils.instance.format_to_readable_area(sheet[:total_area])
        }
        response[:summary][:sheets] += summary_sheets.values.sort_by { |sheet| -sheet[:type] }
        response[:summary][:total_used_area] = DimensionUtils.instance.format_to_readable_area(response[:summary][:total_used_area])

        # Sheets
        grouped_sheets = {}
        # TODO moved to packed bin
        result.packed_bins.each { |bin|

          type_id = _compute_bin_type_id(bin, group, true)

          # Check similarity
          if @sheet_folding
            grouped_sheet_key = "#{type_id}|#{bin.boxes.map { |box| box.data.number }.join('|')}"
            grouped_sheet = grouped_sheets[grouped_sheet_key]
            if grouped_sheet
              grouped_sheet[:count] += 1
              next
            end
          end

          sheet = {
              :type_id => type_id,
              :count => 1,
              :px_length => _to_px(bin.length),
              :px_width => _to_px(bin.width),
              :type => bin.type,
              :length => bin.length.to_l.to_s,
              :width => bin.width.to_l.to_s,
              :efficiency => bin.efficiency,
              :total_length_cuts => bin.total_length_cuts.to_l.to_s,

              :parts => [],
              :grouped_parts => [],
              :leftovers => [],
              :cuts => [],
          }

          # Parts
          grouped_parts = {}
          bin.boxes.each { |box|
            sheet[:parts].push({
                :id => box.data.id,
                :number => box.data.number,
                :name => box.data.name,
                :px_x => _to_px(box.x),
                :px_y => _to_px(box.y),
                :px_length => _to_px(box.length),
                :px_width => _to_px(box.width),
                :length => box.data.cutting_length,
                :width => box.data.cutting_width,
                :rotated => box.rotated,
                :edge_material_names => box.data.edge_material_names,
                :edge_std_dimensions => box.data.edge_std_dimensions,
            })
            unless @hide_part_list
              grouped_part = grouped_parts[box.data.id]
              unless grouped_part
                grouped_part = {
                    :_sorter => (box.data.is_a?(FolderPart) && box.data.number.to_i > 0) ? box.data.number.to_i : box.data.number, # Use a special "_sorter" property because number could contains a "+" suffix
                    :id => box.data.id,
                    :number => box.data.number,
                    :saved_number => box.data.saved_number,
                    :name => box.data.name,
                    :count => 0,
                    :length => box.data.length,
                    :width => box.data.width,
                    :cutting_length => box.data.cutting_length,
                    :cutting_width => box.data.cutting_width,
                    :edge_count => box.data.edge_count,
                    :edge_pattern => box.data.edge_pattern,
                    :edge_decrements => box.data.edge_decrements,
                }
                grouped_parts.store(box.data.id, grouped_part)
              end
              grouped_part[:count] += 1
            end
          }
          sheet[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:_sorter] ] } unless @hide_part_list

          # Leftovers
          bin.leftovers.each { |box|
            sheet[:leftovers].push(
                {
                    :px_x => _to_px(box.x),
                    :px_y => _to_px(box.y),
                    :px_length => _to_px(box.length),
                    :px_width => _to_px(box.width),
                    :length => box.length.to_l.to_s,
                    :width => box.width.to_l.to_s,
                }
            )
          }

          # Cuts
          bin.cuts.each { |cut|
            sheet[:cuts].push(
                {
                    :px_x => _to_px(cut.x),
                    :px_y => _to_px(cut.y),
                    :px_length => _to_px(cut.length),
                    :x => cut.x.to_l.to_s,
                    :y => cut.y.to_l.to_s,
                    :length => cut.length.to_l.to_s,
                    :is_horizontal => cut.is_horizontal,
                }
            )
          }

          if @sheet_folding
            # Add bar to temp grouped sheets hash
            grouped_sheets.store(grouped_sheet_key, sheet)
          else
            # Add bar directly to response
            response[:sheets] << sheet
          end

        }

        if @sheet_folding
          response[:sheets] = grouped_sheets.values
        end

      end

      # Sort sheets
      response[:sheets].sort_by! { |sheet| [ -sheet[:type], -sheet[:efficiency], -sheet[:count]] }

      response
    end

    # -----

    private

    def _compute_bin_type_id(bin, group, used)
      Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{bin.width.to_l.to_s}_#{bin.type}_#{used ? 1 : 0}")
    end

    def _append_bin_to_summary_sheets(bin, group, used, summary_sheets)
      type_id = _compute_bin_type_id(bin, group, used)
      sheet = summary_sheets[type_id]
      unless sheet
        sheet = {
            :type_id => type_id,
            :type => bin.type,
            :count => 0,
            :length => bin.length.to_l.to_s,
            :width => bin.width.to_l.to_s,
            :total_area => 0, # Will be converted to string representation after sum
            :is_used => used,
        }
        summary_sheets[type_id] = sheet
      end
      sheet[:count] += 1
      sheet[:total_area] += Size2d.new(bin.length.to_l, bin.width.to_l).area
    end

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value * 7 # 840px = 120" ~ 3m
    end

  end

end
