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

      @cutlist.groups.each { |group|

        if @group_id && group.id != @group_id
          next
        end

        # The dimensions need to be in Sketchup internal units AND float
        options = BinPacking1D::Options.new
        options.std_length = @std_bar_length
        options.saw_kerf = @saw_kerf # size of saw_kef
        options.trim_size = @trimming # size of trim size (both sides)
        options.max_time = @max_time # the amount of time in seconds for computing, before aborting
        options.tuning_level = @tuning_level # a level 0, 1, 2

        # Create the bin packing engine with given bins and boxes
        e = BinPacking1D::PackEngine.new(options)

        # Add bins from scrap sheets
        @scrap_bar_lengths.split(';').each { |scrap_bar_length|
          e.add_bin(scrap_bar_length.to_f)
        }

        # Add bars from parts, give them a unique ID
        group.parts.each { |part|
          part.entity_ids.each { |p|
            e.add_box(part.cutting_length.to_l.to_f, p)
          }
        }

        result, err = e.run

        case err
        when BinPacking1D::ERROR_NONE
          puts('optimal solution found')
        when BinPacking1D::ERROR_SUBOPT
          puts('suboptimal solution found')
        when BinPacking1D::ERROR_NO_BIN
          puts('no bins available')
        when BinPacking1D::ERROR_NO_PARTS
          puts('no parts to pack')
        when BinPacking1D::ERROR_TIME_EXCEEDED
          puts('time exceeded and no solution found')
        when BinPacking1D::ERROR_NOT_IMPLEMENTED
          puts('feature not implemented yet')
        else
          puts('funky error, contact developpers', err)
        end

        # Compute the cutting diagram

        # Response
        # --------

        # Convert inch float value to pixel
        def to_px(inch_value)
          inch_value * 7 # 840px = 120" ~ 3m
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

        if err > BinPacking1D::ERROR_NONE

          # Engine error -> returns error only

          case err
          when BinPacking1D::ERROR_NO_BIN
            response[:errors] << 'tab.cutlist.cuttingdiagram.error.no_bar'
          end

        else

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

          # Unplaced parts
          unplaced_parts = {}
          result.unplaced_parts.each { |box|
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

          # Bars
          index = 0
          result.bars.each { |bin|

            index += 1
            bar = {
                :index => index,
                :px_length => to_px(bin.length),
                :type => bin.type, # TODO
                :length => bin.length.to_l.to_s,
                :efficiency => bin.efficiency,
                :total_length_cuts => bin.total_length_cuts.to_l.to_s,
                :parts => bin.parts,
                :grouped_parts => [],
                :leftover => bin.leftover,
                :cuts => bin.cuts,
            }

            puts("result for bar #{index}")
            puts("type: ", bar[:type])
            puts("length: ", bar[:length])
            puts("efficiency [0,1]: ", bar[:efficiency])
            puts("leftover/waste: ", bar[:leftover].to_l.to_s)
            puts("parts: ")
            bar[:parts].each do |p|
              print(p[:length].to_l.to_s, " (", p[:id], ") ")
            end
            puts()

            puts("nb of cuts:", bin.nb_of_cuts)
            bar[:cuts].each do |c|
              print(c.to_l.to_s, " ")
            end
            puts()

            response[:bars].push(bar)

          }
        end

        return response
      }

    end

  end

end