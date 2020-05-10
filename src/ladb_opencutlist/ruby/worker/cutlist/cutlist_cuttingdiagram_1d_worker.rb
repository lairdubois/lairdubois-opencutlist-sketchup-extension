module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_1d/packengine'

  class CutlistCuttingdiagram1dWorker

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @std_bar_length = DimensionUtils.instance.str_to_ifloat(settings['std_bar_length']).to_l.to_f
      @scrap_bar_lengths = DimensionUtils.instance.dd_to_ifloats(settings['scrap_bar_lengths'])
      @bar_folding = settings['bar_folding']
      @hide_part_list = settings['hide_part_list']
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f

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
        e.add_bin(scrap_bar_length.to_f)
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

      # Convert inch float value to pixel
      def to_px(inch_value)
        inch_value * 14 # 1680px = 120" ~ 3m
      end

      response = {
          :errors => [],
          :warnings => [],
          :tips => [],

          :options => {
              :hide_part_list => @hide_part_list,
              :px_saw_kerf => to_px(options.saw_kerf),
              :saw_kerf => @saw_kerf.to_l.to_s,
              :trimming => @trimming.to_l.to_s,
              :max_time => @max_time,
              :tuning_level => @tuning_level,
          },

          :unplaced_parts => [],
          :summary => {
              :bars => [],
          },
          :bars => [],
      }

      if err > BinPacking1D::ERROR_SUBOPT

        # Engine error -> returns error only

        case err
        when BinPacking1D::ERROR_NO_BIN
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_bar'
        when BinPacking1D::ERROR_PARAMETERS
          #response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_parts'
          puts("Error in parameters trimsize, sawkerf > 0.25*largest bin")
        when BinPacking1D::ERROR_NO_BOX
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_parts'
        when BinPacking1D::ERROR_TIME_EXCEEDED
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.time_exceeded'
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
        summary_bars = {}
        result.bins.each { |bin|
          type_id = Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{group.def.std_width.to_s}_#{bin.type}")
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
        }
        summary_bars.each { |type_id, bar|
          bar[:total_length] = DimensionUtils.instance.format_to_readable_length(bar[:total_length])
        }
        response[:summary][:bars] += summary_bars.values

        # bars
        grouped_bars = {}
        result.bins.each { |bin|

          bar = {
              :type_id => Digest::MD5.hexdigest("#{bin.length.to_l.to_s}x#{group.def.std_width.to_s}_#{bin.type}"),
              :count => 0,
              :px_length => to_px(bin.length),
              :px_width => to_px(group.def.std_width),
              :type => bin.type, # leftover or new bin
              :length => bin.length.to_l.to_s,
              :width => group.def.std_width.to_s,
              :efficiency => bin.efficiency,
              :total_length_cuts => bin.cut_counts.to_l.to_s,

              :parts => [],
              :grouped_parts => [],
              :leftover => nil,
              :cuts => [],
          }
          grouped_bar_key = bar[:type_id] if @bar_folding

          # Parts
          grouped_parts = {}
          bin.boxes.each { |box|
            bar[:parts].push(
                {
                    :id => box.data.id,
                    :number => box.data.number,
                    :name => box.data.name,
                    :px_x => to_px(box.x),
                    :px_length => to_px(box.length),
                    :length => box.length.to_l.to_s,
                }
            )
            grouped_bar_key += "|#{box.data.number}" if @bar_folding
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
          }
          bar[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:number] ] }

          # Leftover
          bar[:leftover] = {
              :px_x => to_px(bin.current_position),
              :x => bin.current_position,
              :px_length => to_px(bin.current_leftover),
              :length => bin.current_leftover.to_l.to_s,
          }

          # Cuts
          bin.cuts.each { |cut|
            bar[:cuts].push(
                {
                    :px_x => to_px(cut),
                    :x => cut.to_l.to_s,
                }
            )
          }

          if @bar_folding
            # Check similarity
            grouped_bar = grouped_bars[grouped_bar_key]
            unless grouped_bar
              grouped_bars[grouped_bar_key] = bar
              grouped_bar = bar
            end
            grouped_bar[:count] += 1
          else
            # Add bar directly to the list
            response[:bars] << bar
          end

        }

        if @bar_folding
          # Convert grouped bars to array (sort by type DESC and count DESC)
          response[:bars] = grouped_bars.values.sort_by { |bar| [ -bar[:type], -bar[:count] ] }
        end

      end

      response
    end

  end

end