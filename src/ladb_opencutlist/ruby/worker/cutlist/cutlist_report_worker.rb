module Ladb::OpenCutList

  require 'pp'
  require_relative 'cutlist_cuttingdiagram_1d_worker'
  require_relative 'cutlist_cuttingdiagram_2d_worker'

  class CutlistReportWorker

    def initialize(settings, cutlist)

      @cutlist = cutlist

      @remaining_step = @cutlist.groups.count

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      unless @remaining_step == @cutlist.groups.count

        group = @cutlist.groups[@remaining_step - 1]

        case group.material_type
        when MaterialAttributes::TYPE_SOLID_WOOD
          sleep(rand(2))
        when MaterialAttributes::TYPE_SHEET_GOOD

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram2d_options', group.id)

          part_ids = []
          group.parts.each do |part|
            part_ids.push(part.id)
          end

          settings['group_id'] = group.id
          settings['part_ids'] = part_ids

          pp settings

          worker = CutlistCuttingdiagram2dWorker.new(settings, @cutlist)
          worker.run
        when MaterialAttributes::TYPE_DIMENSIONAL

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram1d_options', group.id)

          part_ids = []
          group.parts.each do |part|
            part_ids.push(part.id)
          end

          settings['group_id'] = group.id
          settings['part_ids'] = part_ids

          pp settings

          worker = CutlistCuttingdiagram1dWorker.new(settings, @cutlist)
          worker.run
        end

      end

      response = {
          :errors => [],
          :remaining_step => @remaining_step,
      }

      @remaining_step = @remaining_step - 1

      response
    end

  end

end
