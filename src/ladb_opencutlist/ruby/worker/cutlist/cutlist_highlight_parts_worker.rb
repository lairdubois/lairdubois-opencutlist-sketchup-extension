module Ladb::OpenCutList

  require_relative '../../tool/smart_axes_tool'

  class CutlistHighlightPartsWorker

    def initialize(cutlist,

                   tab_name_to_show_on_quit: nil,

                   part_ids: nil

    )

      @cutlist = cutlist

      @tab_name_to_show_on_quit = tab_name_to_show_on_quit

      @part_ids = part_ids

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = @cutlist.get_parts(@part_ids)

      # Compute part count
      instance_count = parts.inject(0) { |sum, part| sum + part.instance_count_by_part * part.count - part.unused_instance_count }

      if instance_count == 0
        return { :errors => [ 'default.error' ] }
      end

      # Create and activate Smart Axes tool
      model.select_tool(SmartAxesTool.new(
        tab_name_to_show_on_quit: @tab_name_to_show_on_quit,
        highlighted_parts: parts,
        current_action: SmartAxesTool::ACTION_SWAP_LENGTH_WIDTH
      ))

      # Focus SketchUp
      Sketchup.focus if Sketchup.respond_to?(:focus)

      { :success => true }
    end

    # -----

  end

end