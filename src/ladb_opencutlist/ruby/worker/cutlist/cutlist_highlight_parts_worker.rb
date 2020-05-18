module Ladb::OpenCutList

  require_relative '../../tool/highlight_part_tool'

  class CutlistHighlightPartsWorker

    def initialize(cutlist, settings)
      @cutlist = cutlist
      @minimize_on_highlight = settings['minimize_on_highlight']
      @group_id = settings['group_id']
      @part_ids = settings['part_ids']
    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = []
      group = nil
      if @group_id
        group = @cutlist.get_group(@group_id)
        if group
          parts = group.get_real_parts
        end
      elsif @part_ids
        parts = @cutlist.get_real_parts(@part_ids)
      else
        parts = @cutlist.get_real_parts
      end

      # Compute part count
      part_count = parts.inject(0) { |sum, part|  sum + part.count }

      if part_count == 0
        return { :errors => [ 'default.error' ] }
      end

      # Create and activate highlight part tool
      highlight_tool = HighlightPartTool.new(@cutlist, group, parts, part_count, @minimize_on_highlight)
      model.select_tool(highlight_tool)

    end

    # -----

  end

end