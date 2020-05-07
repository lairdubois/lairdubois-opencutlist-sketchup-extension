module Ladb::OpenCutList

  require_relative '../../lib/bin_packing_1d/packengine'

  class CutlistCuttingdiagram1dWorker

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @std_bar_length = DimensionUtils.instance.str_to_ifloat(settings['std_bar_length']).to_l.to_f
      @scrap_bar_lengths = DimensionUtils.instance.dd_to_ifloats(settings['scrap_bar_lengths'])
      @hide_part_list = settings['hide_part_list']
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @max_time = settings['max_time'].to_i
      @tuning_level = settings['tuning_level'].to_i

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      group = @cutlist.get_group(@group_id)
      return { :errors => [ 'default.error' ] } unless group

      # The dimensions need to be in Sketchup internal units AND float
      options = BinPacking1D::Options.new
      options.base_bin_length = @std_bar_length
      options.debug = false
      options.saw_kerf = @saw_kerf # size of saw_kerf
      options.trimsize = @trimming # size of trim size (both sides)
      options.max_time = @max_time # the amount of time in seconds for computing, before aborting
      options.tuning_level = @tuning_level # a level 0, 1, 2

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

      # Compute the cutting diagram

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
              :saw_kerf => options.saw_kerf.to_l.to_s,
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
          puts('no bins available')
        when BinPacking1D::ERROR_NO_PARTS
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_parts'
          puts('no parts to pack')
        when BinPacking1D::ERROR_TIME_EXCEEDED
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.time_exceeded'
          puts('time exceeded and no solution found')
        when BinPacking1D::ERROR_NOT_IMPLEMENTED
          response[:errors] << 'tab.cutlist.cuttingdiagram.error.not_implemented'
          puts('feature not implemented yet')
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
        index = 0
        result.bins.each { |bin|
          index += 1
          id = "#{bin.type},#{bin.length}"
          bar = summary_bars[id]
          unless bar
            bar = {
                :index => index,
                :type => bin.type,
                :count => 0,
                :length => bin.length.to_l.to_s,
                :total_length => 0, # Will be converted to string representation after sum
                :is_used => true,
            }
            summary_bars[id] = bar
          end
          bar[:count] += 1
          bar[:total_length] += bin.length
        }
        summary_bars.each { |id, bar|
          bar[:total_length] = DimensionUtils.instance.format_to_readable_length(bar[:total_length])
        }
        response[:summary][:bars] += summary_bars.values

        # bars
        index = 0
        result.bins.each { |bin|

          index += 1
          bar = {
              :index => index,
              :px_length => to_px(bin.length),
              :px_width => to_px(group.def.std_width),
              :type => bin.type, # leftover or new bin
              :length => bin.length.to_l.to_s,
              :width => group.def.std_width.to_s,
              :efficiency => bin.efficiency,
              :total_length_cuts => bin.total_length_cuts.to_l.to_s,

              :parts => [],
              :grouped_parts => [],
              :leftover => nil,
              :cuts => [],
          }
          response[:bars].push(bar)

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

          # begin: to be deleted after debugging
          puts("result for bin #{index}")
          puts("type: #{bin.type}")
          puts("length: #{bin.length}")
          puts("efficiency [0,1]: #{format('%9.2f', bin.efficiency)}")
          puts("leftover/waste: #{bin.leftover.to_l.to_s}")
          puts("boxes: ")
          bin.boxes.each do |box|
            puts("#{box.length.to_l.to_s} data=#{box.data}")
          end
          puts()

          puts("nb of cuts: #{bin.cuts.length}")
          bin.cuts.each do |c|
            puts("cut @ #{c.to_l.to_s}")
          end
          puts()
          
          puts("unplaced parts: #{result.unplaced_boxes.length}")
          result.unplaced_boxes.each do |box|
            puts("unplaced length=#{box.length} data=#{box.data}")
          end
          # end:

        }
      end


      require 'pp'
      pp response

      response
    end

  end

end