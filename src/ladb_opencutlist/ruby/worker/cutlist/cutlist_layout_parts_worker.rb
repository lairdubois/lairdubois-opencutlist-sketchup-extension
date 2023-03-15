module Ladb::OpenCutList

  require_relative 'cutlist_convert_to_three_worker'

  class CutlistLayoutPartsWorker

    def initialize(settings, cutlist)

      @part_ids = settings.fetch('part_ids', nil)
      @parts_colored = settings.fetch('parts_colored', false)
      @pins_formula = settings.fetch('pins_formula', '')

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
      return { :errors => [ 'tab.cutlist.layout.error.no_part' ] } if parts.empty?

      worker = CutlistConvertToThreeWorker.new(parts, true, @parts_colored, @pins_formula)
      three_model_def = worker.run

      {
        :errors => [],
        :three_model_def => three_model_def.to_hash
      }
    end

  end

end