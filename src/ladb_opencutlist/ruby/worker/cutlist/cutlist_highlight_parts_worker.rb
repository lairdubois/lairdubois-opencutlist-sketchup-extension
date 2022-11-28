module Ladb::OpenCutList

  require_relative '../../tool/highlight_part_tool'

  class CutlistHighlightPartsWorker

    def initialize(settings, cutlist)

      @minimize_on_highlight = settings.fetch('minimize_on_highlight')
      @group_id = settings.fetch('group_id', nil)
      @part_ids = settings.fetch('part_ids', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      material_types_filter = [ MaterialAttributes::TYPE_UNKNOWN, MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD, MaterialAttributes::TYPE_DIMENSIONAL, MaterialAttributes::TYPE_HARDWARE ]
      parts = []
      group = nil
      if @group_id
        group = @cutlist.get_group(@group_id)
        if group && material_types_filter.include?(group.def.material_type)
          parts = group.get_real_parts
        end
      elsif @part_ids
        parts = @cutlist.get_real_parts(@part_ids, material_types_filter)
      else
        parts = @cutlist.get_real_parts(nil, material_types_filter)
      end

      # Compute part count
      instance_count = parts.inject(0) { |sum, part| sum + part.instance_count_by_part * part.count - part.unused_instance_count }

      if instance_count == 0
        return { :errors => [ 'default.error' ] }
      end

      # Create and activate highlight part tool
      highlight_tool = HighlightPartTool.new(@cutlist, group, parts, instance_count, @minimize_on_highlight)
      model.select_tool(highlight_tool)

    end

    # -----

  end

end