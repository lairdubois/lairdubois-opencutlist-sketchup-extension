module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_1d/packengine'

  class CutlistCuttingdiagram1dWorker

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @std_bar_length = DimensionUtils.instance.str_to_ifloat(settings['std_bar_length']).to_l.to_f
      @scrap_bar_lengths = DimensionUtils.instance.dd_to_ifloats(settings['scrap_bar_lengths'])
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @bar_folding = settings['bar_folding']
      @hide_part_list = settings['hide_part_list']
      @wrap_length = DimensionUtils.instance.str_to_ifloat(settings['wrap_length']).to_l.to_f

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      group = @cutlist.get_group(@group_id)
      return { :errors => [ 'default.error' ] } unless group

      # The dimensions need to be in Sketchup internal units AND float
      options = BinPacking1D::Options.new(@std_bar_length, @saw_kerf, @trimming)

      # Create the bin packing engine with given bins and boxes
      e = BinPacking1D::PackEngine.new(options)

      # Add bins from scrap sheets
      @scrap_bar_lengths.split(';').each { |scrap_bar_length|
        e.add_bin(scrap_bar_length.to_l.to_f)
      }

      # Add boxes from parts
      group.parts.each { |part|
        for i in 1..part.count
          e.add_box(part.def.cutting_size.length.to_f, part)
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
              :px_saw_kerf => _to_px(options.saw_kerf),
              :saw_kerf => @saw_kerf.to_l.to_s,
              :trimming => @trimming.to_l.to_s,
              :bar_folding => @bar_folding,
              :hide_part_list => @hide_part_list,
              :wrap_length => @wrap_length,
          },

          :unplaced_parts => [],
          :summary => {
              :bars => [],
              :total_count => 0,
              :total_length => 0,
          },
          :bars => [],
      }

      if err > BinPacking1D::ERROR_SUBOPT

        # Engine error -> returns error only

        case err
        when BinPacking1D::ERROR_NO_BIN
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_bar'
        when BinPacking1D::ERROR_PARAMETERS
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.parameters'
        when BinPacking1D::ERROR_NO_BOX
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_parts'
        when BinPacking1D::ERROR_BAD_ERROR
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.bad_error'
        else
          puts('funky error, contact developpers', err)
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
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
          response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
        end
        if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
          response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase_1d', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
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
                :cutting_length => box.data.cutting_length,
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
        result.unused_bins.each { |bin|
          response[:summary][:bars].push(
              {
                  :type => bin.type,
                  :count => 1,
                  :length => bin.length.to_l.to_s,
                  :total_length => DimensionUtils.instance.format_to_readable_length(bin.length),
                  :is_used => false,
              }
          )
        }
        summary_bars = {}
        result.bins.each { |bin|
          type_id = _compute_bin_type_id(bin, group)
          bar = summary_bars[type_id]
          unless bar
            bar = {
                :type_id => type_id,
                :type => bin.type,
                :count => 0,
                :length => bin.length.to_l.to_s,
                :total_length => 0, # Will be converted to string representation after sum
                :is_used => true,
            }
            summary_bars[type_id] = bar
          end
          bar[:count] += 1
          bar[:total_length] += bin.length
          response[:summary][:total_count] += 1
          response[:summary][:total_length] += bin.length
        }
        summary_bars.each { |type_id, bar|
          bar[:total_length] = DimensionUtils.instance.format_to_readable_length(bar[:total_length])
        }
        response[:summary][:bars] += summary_bars.values.sort_by { |bar| -bar[:type] }
        response[:summary][:total_length] = DimensionUtils.instance.format_to_readable_length(response[:summary][:total_length])

        # Bars
        grouped_bars = {}
        result.bins.each { |bin|

          type_id = _compute_bin_type_id(bin, group)

          # Check similarity
          if @bar_folding
            grouped_bar_key = "#{type_id}|#{bin.boxes.map { |box| box.data.number }.join('|')}"
            grouped_bar = grouped_bars[grouped_bar_key]
            if grouped_bar
              grouped_bar[:count] += 1
              next
            end
          end

          wrap_length = [ @wrap_length, bin.length ].min
          wrap_length = bin.length if wrap_length <= @trimming + @saw_kerf

          bar = {
              :type_id => type_id,
              :count => 1,
              :px_length => _to_px(bin.length),
              :px_width => _to_px(group.def.std_width),
              :type => bin.type, # leftover or new bin
              :length => bin.length.to_l.to_s,
              :width => group.def.std_width.to_s,
              :efficiency => bin.efficiency,

              :slices => [],
              :parts => [],
              :grouped_parts => [],
              :leftover => nil,
              :cuts => [],
          }

          slice_count = (bin.length / wrap_length).ceil
          i = 0
          while i < slice_count do
            bar[:slices].push(
                {
                    :px_length => _to_px([ wrap_length, bin.length - i * wrap_length ].min)
                }
            )
            i += 1
          end

          # Parts
          grouped_parts = {}
          bin.boxes.each { |box|
            bar[:parts].push({
                :id => box.data.id,
                :number => box.data.number,
                :name => box.data.name,
                :length => box.length.to_l.to_s,
                :slices => _to_slices(box.x, box.length, wrap_length),
            })
            unless @hide_part_list
              grouped_part = grouped_parts[box.data.id]
              unless grouped_part
                grouped_part = {
                    :id => box.data.id,
                    :number => box.data.number,
                    :saved_number => box.data.saved_number,
                    :name => box.data.name,
                    :count => 0,
                    :length => box.data.length,
                    :cutting_length => box.data.cutting_length,
                }
                grouped_parts.store(box.data.id, grouped_part)
              end
              grouped_part[:count] += 1
            end
          }
          bar[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:number] ] } unless @hide_part_list

          # Leftover
          bar[:leftover] = {
              :x => bin.current_position,
              :length => bin.current_leftover.to_l.to_s,
              :slices => _to_slices(bin.current_position, bin.current_leftover, wrap_length),
          }

          # Cuts
          bin.cuts.each { |cut|
            bar[:cuts].push(
                {
                    :x => cut.to_l.to_s,
                    :slices => _to_slices(cut, 0, wrap_length)
                }
            )
          }

          if @bar_folding
            # Add bar to temp grouped bars hash
            grouped_bars.store(grouped_bar_key, bar)
          else
            # Add bar directly to response
            response[:bars] << bar
          end

        }

        if @bar_folding
          # Convert grouped bars to array (sort by type DESC and count DESC)
          response[:bars] = grouped_bars.values.sort_by { |bar| [ -bar[:type], -bar[:efficiency], -bar[:count] ] }
        end

      end

      response
    end

    # -----

    private

    def _compute_bin_type_id(bin, group)
      Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{group.def.std_width.to_s}_#{bin.type}")
    end

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value * 7 # 840px = 120" ~ 3m
    end

    # Convert inch float value to slice index
    def _to_slice_index(inch_value, wrap_length)
      wrap_length == 0 ? 0 : (inch_value / wrap_length).floor
    end

    def _to_slices(x, length, wrap_length)

      start_slice_index = _to_slice_index(x, wrap_length)
      end_slice_index = _to_slice_index(x + length, wrap_length)

      slices = []
      slice_index = start_slice_index
      current_x = x
      remaining_length = length
      while slice_index <= end_slice_index do
        bar_slice_x = wrap_length * slice_index
        part_slice_x = current_x - bar_slice_x
        part_slice_length = [wrap_length - part_slice_x, remaining_length ].min
        slices.push(
            {
                :index => slice_index,
                :px_x => _to_px(part_slice_x),
                :px_length => _to_px(part_slice_length),
            }
        )
        slice_index += 1
        current_x += part_slice_length
        remaining_length -= part_slice_length
      end

      slices
    end

  end

end