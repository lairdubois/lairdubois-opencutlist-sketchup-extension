module Ladb::OpenCutList

  require_relative '../../model/attributes/material_attributes'

  class CutlistEstimateWorker

    def initialize(cutlist,

                   hidden_group_ids: []

    )

      @cutlist = cutlist

      @hidden_group_ids = hidden_group_ids

      @cutlist_groups = @cutlist.groups.select { |group| group.material_type != MaterialAttributes::TYPE_UNKNOWN && !@hidden_group_ids.include?(group.id) }
      @remaining_step = @cutlist_groups.length

      @runs = 2
      @run_index = 0
      @run_progress = 0.0
      @cancelled = false

    end

    # -----

    def run(action = :start)
      case action
      when :start
        return {
          runs: @runs,
          running: true,
          run_index: @run_index,
          run_progress: @run_progress,
        }
      when :advance
        return {
          cancelled: true
        } if @cancelled
        @run_progress = [ @run_progress + 0.1, 1.0 ].min
        if @run_progress == 1.0
          @run_index += 1
          @run_progress = 0.0
        end
        return {
          running: true,
          run_index: @run_index,
          run_progress: @run_progress,
        } if @run_index < @runs
        return {
        }
      when :next
        @run_index = [ @run_index + 1, @runs - 1].min
        return {
        }
      when :cancel
        @cancelled = true
        return {
        }
      end
      {}
    end

  end

end