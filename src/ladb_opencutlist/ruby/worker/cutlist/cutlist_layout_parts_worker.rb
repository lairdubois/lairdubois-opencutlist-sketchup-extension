module Ladb::OpenCutList

  require_relative 'cutlist_convert_to_three_worker'

  class CutlistLayoutPartsWorker

    def initialize(settings, cutlist)

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

      worker = CutlistConvertToThreeWorker.new(parts, true)
      three_model_def = worker.run

      {
        :errors => [],
        :warnings => [],
        :three_model_def => three_model_def.to_hash
      }
    end

  end

end