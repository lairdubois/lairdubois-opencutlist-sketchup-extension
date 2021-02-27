module Ladb::OpenCutList

  require_relative 'cutlist_cuttingdiagram_1d_worker'
  require_relative 'cutlist_cuttingdiagram_2d_worker'

  class CutlistReportWorker

    def initialize(settings, cutlist)

      @cutlist = cutlist

      @remaining_step = @cutlist.groups.count
      @report = {
          :errors => [],
          :remaining_step => 0,
          :warnings => [],
          :tips => [],
          :solid_woods => [],
          :sheet_goods => [],
          :dimensionals => [],
          :edges => [],
          :accesories => [],
      }

      # Setup caches
      @material_attributes_cache = {}

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      unless @remaining_step == @cutlist.groups.count

        group = @cutlist.groups[@cutlist.groups.count - @remaining_step - 1]

        case group.material_type

          when MaterialAttributes::TYPE_SOLID_WOOD

            @report[:solid_woods].push({
                :material_name => group.material_name,
                :material_display_name => group.material_display_name,
                :material_type => group.material_type,
                :material_color => group.material_color,
                :std_available => group.std_available,
                :std_dimension_stipped_name => group.std_dimension_stipped_name,
                :std_dimension => group.std_dimension,
                :total_cutting_volume => group.total_cutting_volume,
            })

           when MaterialAttributes::TYPE_SHEET_GOOD

            settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram2d_options', group.id)
            settings['group_id'] = group.id

            if settings['std_sheet'] == ''
              material_attributes = _get_material_attributes(group.material_name)
              std_sizes = material_attributes.std_sizes.split(';')
              settings['std_sheet'] = std_sizes[0] unless std_sizes.empty?
            end

            worker = CutlistCuttingdiagram2dWorker.new(settings, @cutlist)
            cuttingdiagram2d = worker.run

            @report[:sheet_goods].push({
                :material_name => group.material_name,
                :material_display_name => group.material_display_name,
                :material_type => group.material_type,
                :material_color => group.material_color,
                :std_available => group.std_available,
                :std_dimension_stipped_name => group.std_dimension_stipped_name,
                :std_dimension => group.std_dimension,
                :total_used_count => cuttingdiagram2d[:summary][:total_used_count],
                :total_used_area => cuttingdiagram2d[:summary][:total_used_area],
            })

          when MaterialAttributes::TYPE_DIMENSIONAL

            settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram1d_options', group.id)
            settings['group_id'] = group.id

            if settings['std_bar'] == ''
              material_attributes = _get_material_attributes(group.material_name)
              std_sizes = material_attributes.std_lengths.split(';')
              settings['std_bar'] = std_sizes[0] unless std_sizes.empty?
            end

            worker = CutlistCuttingdiagram1dWorker.new(settings, @cutlist)
            cuttingdiagram1d = worker.run

            @report[:dimensionals].push({
                :material_name => group.material_name,
                :material_display_name => group.material_display_name,
                :material_type => group.material_type,
                :material_color => group.material_color,
                :std_available => group.std_available,
                :std_dimension_stipped_name => group.std_dimension_stipped_name,
                :std_dimension => group.std_dimension,
                :total_used_count => cuttingdiagram1d[:summary][:total_used_count],
                :total_used_length => cuttingdiagram1d[:summary][:total_used_length],
            })

          when MaterialAttributes::TYPE_EDGE

            @report[:edges].push({
                :material_name => group.material_name,
                :material_display_name => group.material_display_name,
                :material_type => group.material_type,
                :material_color => group.material_color,
                :std_available => group.std_available,
                :std_dimension_stipped_name => group.std_dimension_stipped_name,
                :std_dimension => group.std_dimension,
            })

          when MaterialAttributes::TYPE_ACCESSORY

            @report[:accesories].push({
                :material_name => group.material_name,
                :material_display_name => group.material_display_name,
                :material_type => group.material_type,
                :material_color => group.material_color,
                :std_available => group.std_available,
                :std_dimension_stipped_name => group.std_dimension_stipped_name,
                :std_dimension => group.std_dimension,
            })

        end

      end

      if @remaining_step > 0
        response = {
            :remaining_step => @remaining_step,
        }
        @remaining_step = @remaining_step - 1
      else
        response = @report
      end

      response
    end

    # -----

    private

    # -- Cache Utils --

    # MaterialAttributes

    def _get_material_attributes(material_name)
      material = Sketchup.active_model.materials[material_name]
      key = material ? material.name : '$EMPTY$'
      unless @material_attributes_cache.has_key? key
        @material_attributes_cache[key] = MaterialAttributes.new(material)
      end
      @material_attributes_cache[key]
    end

  end

end
