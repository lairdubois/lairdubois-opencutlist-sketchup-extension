module Ladb::OpenCutList

  require_relative 'cutlist_packing_worker'

  class CutlistPackingImproveWorker < AbstractCutlistPackingWorker

    def initialize(cutlist, packing

    )

      @cutlist = cutlist
      @packing = packing

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'default.error' ] } unless @packing && @packing.def.group

      { :cancelled => true }
    end

  end

end