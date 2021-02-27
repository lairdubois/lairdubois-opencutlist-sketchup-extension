module Ladb::OpenCutList

  require_relative 'cutlist_cuttingdiagram_1d_worker'
  require_relative 'cutlist_cuttingdiagram_2d_worker'
  require_relative '../../model/report/report_def'
  require_relative '../../model/report/report_entrydef'

  class CutlistReportWorker

    def initialize(settings, cutlist)

      @cutlist = cutlist

      @remaining_step = @cutlist.groups.count
      @report = {
          :errors => [],
          :remaining_step => 0,
          :warnings => [],
          :tips => [],
          :solid_woods => [],
          :sheet_goods => [],
          :dimensionals => [],
          :edges => [],
          :accessories => [],
      }

      @report_def = ReportDef.new

      # Setup caches
      @material_attributes_cache = {}

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      unless @remaining_step == @cutlist.groups.count

        cutlist_group = @cutlist.groups[@cutlist.groups.count - @remaining_step - 1]
        report_group_def = @report_def.get_group_def(cutlist_group.material_type)

        case cutlist_group.material_type

        when MaterialAttributes::TYPE_SOLID_WOOD

          report_entry_def = SolidWoodReportEntryDef.new(cutlist_group)
          report_entry_def.total_volume = cutlist_group.def.total_cutting_volume

          report_group_def.add_entry_def(report_entry_def)
          report_group_def.total_volume = report_group_def.total_volume + report_entry_def.total_volume

        when MaterialAttributes::TYPE_SHEET_GOOD

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram2d_options', cutlist_group.id)
          settings['group_id'] = cutlist_group.id

          if settings['std_sheet'] == ''
            material_attributes = _get_material_attributes(cutlist_group.material_name)
            std_sizes = material_attributes.std_sizes.split(';')
            settings['std_sheet'] = std_sizes[0] unless std_sizes.empty?
          end

          worker = CutlistCuttingdiagram2dWorker.new(settings, @cutlist)
          cuttingdiagram2d = worker.run

          report_entry_def = SheetGoodReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cuttingdiagram2d[:summary][:total_used_count].to_i
          report_entry_def.total_area = cuttingdiagram2d[:summary][:total_used_area].to_f

          report_group_def.add_entry_def(report_entry_def)
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count
          report_group_def.total_area = report_group_def.total_area + report_entry_def.total_area

        when MaterialAttributes::TYPE_DIMENSIONAL

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram1d_options', cutlist_group.id)
          settings['group_id'] = cutlist_group.id

          if settings['std_bar'] == ''
            material_attributes = _get_material_attributes(cutlist_group.material_name)
            std_sizes = material_attributes.std_lengths.split(';')
            settings['std_bar'] = std_sizes[0] unless std_sizes.empty?
          end

          worker = CutlistCuttingdiagram1dWorker.new(settings, @cutlist)
          cuttingdiagram1d = worker.run

          report_entry_def = DimensionalReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cuttingdiagram1d[:summary][:total_used_count].to_i
          report_entry_def.total_length = cuttingdiagram1d[:summary][:total_used_length].to_f

          report_group_def.add_entry_def(report_entry_def)
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count
          report_group_def.total_length = report_group_def.total_length + report_entry_def.total_length

        when MaterialAttributes::TYPE_EDGE

          report_entry_def = EdgeReportEntryDef.new(cutlist_group)
          report_entry_def.total_length = cutlist_group.def.total_cutting_length

          report_group_def.add_entry_def(report_entry_def)
          report_group_def.total_length = report_group_def.total_length + report_entry_def.total_length

        when MaterialAttributes::TYPE_ACCESSORY

          report_entry_def = AccessoryReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cutlist_group.def.part_count

          report_group_def.add_entry_def(report_entry_def)
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count

        end

      end

      if @remaining_step > 0
        response = {
            :remaining_step => @remaining_step,
        }
        @remaining_step = @remaining_step - 1
      else

        # Create the report
        report = @report_def.create_report

        response = report.to_hash

      end

      response
    end

    # -----

    private

    # -- Cache Utils --

    # MaterialAttributes

    def _get_material_attributes(material_name)
      material = Sketchup.active_model.materials[material_name]
      key = material ? material.name : '$EMPTY$'
      unless @material_attributes_cache.has_key? key
        @material_attributes_cache[key] = MaterialAttributes.new(material)
      end
      @material_attributes_cache[key]
    end

  end

end
