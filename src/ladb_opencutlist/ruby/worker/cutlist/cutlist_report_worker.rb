module Ladb::OpenCutList

  require_relative 'cutlist_cuttingdiagram_1d_worker'
  require_relative 'cutlist_cuttingdiagram_2d_worker'
  require_relative '../../model/report/report_def'
  require_relative '../../model/report/report_entry_def'

  class CutlistReportWorker

    def initialize(settings, cutlist)

      @cutlist = cutlist

      @remaining_step = @cutlist.groups.count

      @report_def = ReportDef.new

      # Setup caches
      @material_attributes_cache = {}
      @definition_attributes_cache = {}

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      unless @remaining_step == @cutlist.groups.count

        cutlist_group = @cutlist.groups[@cutlist.groups.count - @remaining_step - 1]
        report_group_def = @report_def.group_defs[cutlist_group.material_type]
        report_entry_def = nil

        case cutlist_group.material_type

        when MaterialAttributes::TYPE_SOLID_WOOD

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.volumic_mass.to_f
          std_prices = material_attributes.std_prices.to_f

          report_entry_def = SolidWoodReportEntryDef.new(cutlist_group)
          report_entry_def.total_volume = cutlist_group.def.total_cutting_volume
          report_entry_def.total_mass = cutlist_group.def.total_cutting_volume * volumic_mass unless volumic_mass == 0
          report_entry_def.total_cost = cutlist_group.def.total_cutting_volume * std_prices unless std_prices == 0

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_volume = report_group_def.total_volume + report_entry_def.total_volume

        when MaterialAttributes::TYPE_SHEET_GOOD

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.volumic_mass.to_f
          std_prices = material_attributes.std_prices.to_f

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram2d_options', cutlist_group.id)
          settings['group_id'] = cutlist_group.id
          settings['bar_folding'] = false     # Remove unneeded computations
          settings['hide_part_list'] = true   # Remove unneeded computations

          if settings['std_sheet'] == ''
            std_sizes = material_attributes.std_sizes.split(';')
            settings['std_sheet'] = std_sizes[0] unless std_sizes.empty?
          end

          worker = CutlistCuttingdiagram2dWorker.new(settings, @cutlist)
          cuttingdiagram2d = worker.run

          report_entry_def = SheetGoodReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cuttingdiagram2d.summary.total_used_count
          report_entry_def.total_area = cuttingdiagram2d.summary.def.total_used_area
          report_entry_def.total_mass = report_entry_def.total_area * cutlist_group.def.std_thickness * volumic_mass unless volumic_mass == 0
          report_entry_def.total_cost = report_entry_def.total_area * cutlist_group.def.std_thickness * std_prices unless std_prices == 0

          cuttingdiagram2d.summary.sheets.each do |cuttingdiagram2d_summary_sheet|

            next unless cuttingdiagram2d_summary_sheet.is_used

            report_entry_sheet_def = SheetGoodReportEntrySheetDef.new(cuttingdiagram2d_summary_sheet)
            report_entry_sheet_def.total_mass = cuttingdiagram2d_summary_sheet.def.total_area * cutlist_group.def.std_thickness * volumic_mass unless volumic_mass == 0
            report_entry_sheet_def.total_cost = cuttingdiagram2d_summary_sheet.def.total_area * cutlist_group.def.std_thickness * std_prices unless std_prices == 0
            report_entry_def.sheet_defs << report_entry_sheet_def

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count
          report_group_def.total_area = report_group_def.total_area + report_entry_def.total_area

        when MaterialAttributes::TYPE_DIMENSIONAL

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.volumic_mass.to_f
          std_prices = material_attributes.std_prices.to_f

          settings = Plugin.instance.get_model_preset('cutlist_cuttingdiagram1d_options', cutlist_group.id)
          settings['group_id'] = cutlist_group.id
          settings['bar_folding'] = false     # Remove unneeded computations
          settings['hide_part_list'] = true   # Remove unneeded computations

          if settings['std_bar'] == ''
            std_sizes = material_attributes.std_lengths.split(';')
            settings['std_bar'] = std_sizes[0] unless std_sizes.empty?
          end

          worker = CutlistCuttingdiagram1dWorker.new(settings, @cutlist)
          cuttingdiagram1d = worker.run

          report_entry_def = DimensionalReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cuttingdiagram1d.summary.total_used_count
          report_entry_def.total_length = cuttingdiagram1d.summary.def.total_used_length
          report_entry_def.total_mass = report_entry_def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * volumic_mass unless volumic_mass == 0
          report_entry_def.total_cost = report_entry_def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * std_prices unless std_prices == 0

          cuttingdiagram1d.summary.bars.each do |cuttingdiagram1d_summary_bar|

            next unless cuttingdiagram1d_summary_bar.is_used

            report_entry_bar_def = DimensionalReportEntryBarDef.new(cuttingdiagram1d_summary_bar)
            report_entry_bar_def.total_mass = cuttingdiagram1d_summary_bar.def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * volumic_mass unless volumic_mass == 0
            report_entry_bar_def.total_cost = cuttingdiagram1d_summary_bar.def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * std_prices unless std_prices == 0
            report_entry_def.bar_defs << report_entry_bar_def

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count
          report_group_def.total_length = report_group_def.total_length + report_entry_def.total_length

        when MaterialAttributes::TYPE_EDGE

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.volumic_mass.to_f
          std_prices = material_attributes.std_prices.to_f

          report_entry_def = EdgeReportEntryDef.new(cutlist_group)
          report_entry_def.total_length = cutlist_group.def.total_cutting_length
          report_entry_def.total_mass = cutlist_group.def.total_cutting_volume * volumic_mass unless volumic_mass == 0
          report_entry_def.total_cost = cutlist_group.def.total_cutting_volume * std_prices unless std_prices == 0

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_length = report_group_def.total_length + report_entry_def.total_length

        when MaterialAttributes::TYPE_ACCESSORY

          report_entry_def = AccessoryReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cutlist_group.def.part_count

          cutlist_group.parts.each do |cutlist_part|

            if cutlist_part.is_a?(FolderPart)
              cutlist_part.children.each { |cutlist_child_part|
                _compute_accessory_part(cutlist_child_part, report_entry_def)
              }
            else
              _compute_accessory_part(cutlist_part, report_entry_def)
            end

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count

        end

        unless report_entry_def.nil?

          report_group_def.total_mass = report_group_def.total_mass + report_entry_def.total_mass
          report_group_def.total_cost = report_group_def.total_cost + report_entry_def.total_cost

          @report_def.total_mass = @report_def.total_mass + report_entry_def.total_mass
          @report_def.total_cost = @report_def.total_cost + report_entry_def.total_cost

        end

      end

      if @remaining_step > 0
        response = {
            :remaining_step => @remaining_step,
        }
        @remaining_step = @remaining_step - 1
      else

        # Errors
        if @report_def.group_defs.values.select { |group_def| !group_def.entry_defs.empty? }.length == 0
          @report_def.errors << 'tab.cutlist.report.error.no_typed_material_parts'
        end

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

    # DefinitionAttributes

    def _get_definition_attributes(definition_name)
      definition = Sketchup.active_model.definitions[definition_name]
      key = definition ? definition.name : '$EMPTY$'
      unless @definition_attributes_cache.has_key? key
        @definition_attributes_cache[key] = DefinitionAttributes.new(definition, true)
      end
      @definition_attributes_cache[key]
    end

    # -----

    def _compute_accessory_part(cutlist_part, report_entry_def)

      report_entry_part_def = AccessoryReportEntryPartDef.new(cutlist_part)
      report_entry_def.part_defs << report_entry_part_def

      definition_attributes = _get_definition_attributes(cutlist_part.def.definition_id)

      unit_mass = definition_attributes.unit_mass
      unless unit_mass.empty?
        report_entry_part_def.total_mass = unit_mass.to_f * cutlist_part.def.count
        report_entry_def.total_mass = report_entry_def.total_mass + report_entry_part_def.total_mass
      end

      unit_price = definition_attributes.unit_price
      unless unit_price.empty?
        report_entry_part_def.total_cost = unit_price.to_f * cutlist_part.def.count
        report_entry_def.total_cost = report_entry_def.total_cost + report_entry_part_def.total_cost
      end

    end

  end

end
