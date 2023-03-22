module Ladb::OpenCutList

  require_relative '../../tool/highlight_part_tool'

  class CutlistHighlightPartsWorker

    def initialize(settings, cutlist)

      @minimize_on_highlight = settings.fetch('minimize_on_highlight')
      @part_ids = settings.fetch('part_ids', nil)
      @group_id = settings.fetch('group_id', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = @cutlist.get_real_parts(@part_ids)

      # Retrieve group (if given)
      group = nil
      group = @cutlist.get_group(@group_id) if @group_id

      # Compute part count
      instance_count = parts.inject(0) { |sum, part| sum + part.instance_count_by_part * part.count - part.unused_instance_count }

      if instance_count == 0
        return { :errors => [ 'default.error' ] }
      end

      # Create and activate highlight part tool
      model.select_tool(HighlightPartTool.new(@cutlist, group, parts, instance_count, @minimize_on_highlight))

      # Focus SketchUp
      Sketchup.focus if Sketchup.respond_to?(:focus)

      { :success => true }
    end

    # -----

  end

end