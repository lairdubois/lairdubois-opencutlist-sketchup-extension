module Ladb::OpenCutList

  require_relative 'cutlist_convert_to_three_worker'

  class CutlistLayoutPartsWorker

    def initialize(cutlist,

                   part_ids: ,
                   all_instances: true,

                   parts_colored: false,
                   pins_formula: ''

    )

      @cutlist = cutlist

      @part_ids = part_ids
      @all_instances = all_instances

      @parts_colored = parts_colored
      @pins_formula = pins_formula

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = @cutlist.get_parts(@part_ids)
      return { :errors => [ 'tab.cutlist.layout.error.no_part' ] } if parts.empty?

      worker = CutlistConvertToThreeWorker.new(parts,
         all_instances: @all_instances,
         parts_colored: @parts_colored,
         pins_formula: @pins_formula
      )
      three_model_def = worker.run

      {
        :errors => [],
        :three_model_def => three_model_def.to_hash
      }
    end

  end

end