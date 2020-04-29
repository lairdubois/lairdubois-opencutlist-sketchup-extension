module Ladb::OpenCutList

  class CutlistHighlightPartsWorker

    def initialize(cutlist, group_id, part_ids)
      @cutlist = cutlist
      @grou_id = group_id
      @part_ids = part_ids
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      return { :errors => [ 'default.error' ] } unless @cutlist

      # Retrieve parts
      parts = []
      displayed_part = nil
      displayed_group = nil
      if @group_id
        group = @cutlist.get_group(@group_id)
        if group
          parts = group.get_real_parts
          displayed_group = group
        end
      elsif @part_ids
        parts = @cutlist.get_real_parts(@part_ids)
        displayed_part = parts.first if parts.length == 1
      else
        parts = @cutlist.get_real_parts
      end

      # Compute entity count
      entity_count = parts.inject(0) {|sum, part|  sum + part.count }

      if entity_count == 0

        # Retrieve cutlist
        return { :errors => [ 'default.error' ] }

      end

      # Compute text infos
      if displayed_part

        text_line_1 = '[' + displayed_part.number + '] ' + displayed_part.name
        text_line_2 = displayed_part.labels.join(' | ')
        text_line_3 = displayed_part.length.to_s + ' x ' + displayed_part.width.to_s + ' x ' + displayed_part.thickness.to_s +
            (displayed_part.final_area.nil? ? '' : " (#{displayed_part.final_area})") +
            ' | ' + entity_count.to_s + ' ' + Plugin.instance.get_i18n_string(entity_count > 1 ? 'default.part_plural' : 'default.part_single') +
            ' | ' + (displayed_part.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : displayed_part.material_name)

      elsif displayed_group

        text_line_1 = (displayed_group.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : displayed_group.material_name + (displayed_group.std_dimension.empty? ? '' : ' / ' + displayed_group.std_dimension))
        text_line_2 = ''
        text_line_3 = entity_count.to_s + ' ' + Plugin.instance.get_i18n_string(entity_count > 1 ? 'default.part_plural' : 'default.part_single')

      else

        text_line_1 = ''
        text_line_2 = ''
        text_line_3 = entity_count.to_s + ' ' + Plugin.instance.get_i18n_string(entity_count > 1 ? 'default.part_plural' : 'default.part_single')

      end

      # Create and activate highlight part tool
      highlight_tool = HighlightPartTool.new(text_line_1, text_line_2, text_line_3, parts)
      model.select_tool(highlight_tool)

    end

    # -----

  end

end