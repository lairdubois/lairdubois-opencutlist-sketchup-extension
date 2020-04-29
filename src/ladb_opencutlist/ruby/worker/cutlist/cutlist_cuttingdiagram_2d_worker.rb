module Ladb::OpenCutList

  class CutlistCuttingdiagram2dWorker

    def initialize(settings, cutlist)
      @group_id = settings['group_id']
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_length']).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_width']).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxd_to_ifloats(settings['scrap_sheet_sizes'])
      @grained = settings['grained']
      @hide_part_list = settings['hide_part_list']
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @presort = BinPacking2D::Packing2D.valid_presort(settings['presort'])
      @stacking = BinPacking2D::Packing2D.valid_stacking(settings['stacking'])
      @bbox_optimization = BinPacking2D::Packing2D.valid_bbox_optimization(settings['bbox_optimization'])

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      group = @cutlist.get_group(@group_id)
      if group

        # The dimensions need to be in Sketchup internal units AND float
        options = BinPacking2D::Options.new
        options.base_bin_length = @std_sheet_length
        options.base_bin_width = @std_sheet_width
        options.rotatable = !@grained
        options.saw_kerf = @saw_kerf
        options.trimming = @trimming
        options.stacking = @stacking
        options.bbox_optimization = @bbox_optimization
        options.presort = @presort

        # Create the bin packing engine with given bins and boxes
        e = BinPacking2D::PackEngine.new(options)

        # Add bins from scrap sheets
        @scrap_sheet_sizes.split(';').each { |scrap_sheet_size|
          size2d = Size2d.new(scrap_sheet_size)
          e.add_bin(size2d.length.to_f, size2d.width.to_f)
        }

        # Add boxes from parts
        group.parts.each { |part|
          for i in 1..part.count
            e.add_box(part.def.cutting_size.length.to_f, part.def.cutting_size.width.to_f, part)
          end
        }

        # Compute the cutting diagram
        result, err = e.run

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
                :grained => @grained,
                :hide_part_list => @hide_part_list,
                :px_saw_kerf => to_px(options.saw_kerf),
                :saw_kerf => options.saw_kerf.to_l.to_s,
                :trimming => options.trimming.to_l.to_s,
                :stacking => @stacking,
                :bbox_optimization => @bbox_optimization,
                :presort => @presort,
            },

            :unplaced_parts => [],
            :summary => {
                :sheets => [],
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
          if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0 || group.edge_decremented
            response[:warnings] << 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions'
          end
          if material_attributes.l_length_increase > 0 || material_attributes.l_width_increase > 0
            response[:warnings] << [ 'tab.cutlist.cuttingdiagram.warning.cutting_dimensions_increase', { :material_name => group.material_name, :length_increase => material_attributes.length_increase, :width_increase => material_attributes.width_increase } ]
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
          result.unused_bins.each {|bin|
            response[:summary][:sheets].push(
                {
                    :type => bin.type,
                    :count => 1,
                    :length => bin.length.to_l.to_s,
                    :width => bin.width.to_l.to_s,
                    :area => DimensionUtils.instance.format_to_readable_area(Size2d.new(bin.length.to_l, bin.width.to_l).area),
                    :is_used => false,
                }
            )
          }
          summary_sheets = {}
          index = 0
          result.original_bins.each { |bin|
            index += 1
            id = "#{bin.type},#{bin.length},#{bin.width}"
            sheet = summary_sheets[id]
            unless sheet
              sheet = {
                  :index => index,
                  :type => bin.type,
                  :count => 0,
                  :length => bin.length.to_l.to_s,
                  :width => bin.width.to_l.to_s,
                  :area => 0, # Will be converted to string representation after sum
                  :is_used => true,
              }
              summary_sheets[id] = sheet
            end
            sheet[:count] += 1
            sheet[:area] += Size2d.new(bin.length.to_l, bin.width.to_l).area
          }
          summary_sheets.each { |id, sheet|
            sheet[:area] = DimensionUtils.instance.format_to_readable_area(sheet[:area])
          }
          response[:summary][:sheets] += summary_sheets.values

          # Sheets
          index = 0
          result.original_bins.each { |bin|

            index += 1
            sheet = {
                :index => index,
                :px_length => to_px(bin.length),
                :px_width => to_px(bin.width),
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
            response[:sheets].push(sheet)

            # Parts
            grouped_parts = {}
            bin.boxes.each { |box|
              sheet[:parts].push(
                  {
                      :id => box.data.id,
                      :number => box.data.number,
                      :name => box.data.name,
                      :px_x => to_px(box.x),
                      :px_y => to_px(box.y),
                      :px_length => to_px(box.length),
                      :px_width => to_px(box.width),
                      :length => box.length.to_l.to_s,
                      :width => box.width.to_l.to_s,
                      :rotated => box.rotated,
                      :edge_material_names => box.data.edge_material_names,
                      :edge_std_dimensions => box.data.edge_std_dimensions,
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
            }
            sheet[:grouped_parts] = grouped_parts.values.sort_by { |v| [ v[:number] ] }

            # Leftovers
            bin.leftovers.each { |box|
              sheet[:leftovers].push(
                  {
                      :px_x => to_px(box.x),
                      :px_y => to_px(box.y),
                      :px_length => to_px(box.length),
                      :px_width => to_px(box.width),
                      :length => box.length.to_l.to_s,
                      :width => box.width.to_l.to_s,
                  }
              )
            }

            # Cuts
            bin.cuts.each { |cut|
              sheet[:cuts].push(
                  {
                      :px_x => to_px(cut.x),
                      :px_y => to_px(cut.y),
                      :px_length => to_px(cut.length),
                      :x => cut.x.to_l.to_s,
                      :y => cut.y.to_l.to_s,
                      :length => cut.length.to_l.to_s,
                      :is_horizontal => cut.is_horizontal,
                  }
              )
            }

          }

        end

        response
      end

    end

  end

end