module Ladb::OpenCutList

  require_relative 'cutlist_cuttingdiagram_1d_worker'
  require_relative 'cutlist_cuttingdiagram_2d_worker'
  require_relative '../../model/report/report_def'
  require_relative '../../model/report/report_entry_def'

  class CutlistReportWorker

    def initialize(settings, cutlist)

      @hidden_group_ids = settings['hidden_group_ids']
      @solid_wood_coefficient = [ 1.0, "#{settings['solid_wood_coefficient']}".tr(',', '.').to_f ].max

      @cutlist = cutlist

      @cutlist_groups = @cutlist.groups.select { |group| group.material_type != MaterialAttributes::TYPE_UNKNOWN && !@hidden_group_ids.include?(group.id) }
      @remaining_step = @cutlist_groups.count
      @starting = true

      @report_def = ReportDef.new
      @report_def.solid_wood_coefficient = @solid_wood_coefficient

      # Setup caches
      @material_attributes_cache = {}
      @definition_attributes_cache = {}
      @model_unit_is_metric = DimensionUtils.instance.model_unit_is_metric

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist

      unless @starting || @cutlist_groups.count == 0

        cutlist_group = @cutlist_groups[@cutlist_groups.count - @remaining_step - 1]
        report_group_def = @report_def.group_defs[cutlist_group.material_type]
        report_entry_def = nil

        case cutlist_group.material_type

        when MaterialAttributes::TYPE_SOLID_WOOD

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.h_volumic_mass
          std_price = _get_std_price([ cutlist_group.def.std_thickness ], material_attributes)

          report_entry_def = SolidWoodReportEntryDef.new(cutlist_group)
          report_entry_def.volumic_mass = volumic_mass
          report_entry_def.std_price = std_price
          report_entry_def.total_volume = cutlist_group.def.total_cutting_volume * @solid_wood_coefficient
          report_entry_def.total_mass = cutlist_group.def.total_cutting_volume * @solid_wood_coefficient * _uv_to_inch3(volumic_mass[:unit], volumic_mass[:val]) unless volumic_mass[:val] == 0
          report_entry_def.total_cost = cutlist_group.def.total_cutting_volume * @solid_wood_coefficient * _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness) unless std_price[:val] == 0

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_volume += report_entry_def.total_volume

        when MaterialAttributes::TYPE_SHEET_GOOD

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.h_volumic_mass

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
          report_entry_def.errors += cuttingdiagram2d.errors
          report_entry_def.volumic_mass = volumic_mass
          report_entry_def.total_count = cuttingdiagram2d.summary.total_used_count
          report_entry_def.total_area = cuttingdiagram2d.summary.def.total_used_area

          cuttingdiagram2d.summary.sheets.each do |cuttingdiagram2d_summary_sheet|

            next unless cuttingdiagram2d_summary_sheet.is_used

            std_price = _get_std_price([cutlist_group.def.std_thickness, Size2d.new(cuttingdiagram2d_summary_sheet.def.length, cuttingdiagram2d_summary_sheet.width) ], material_attributes)

            report_entry_sheet_def = SheetGoodReportEntrySheetDef.new(cuttingdiagram2d_summary_sheet)
            report_entry_sheet_def.std_price = std_price
            report_entry_sheet_def.total_mass = cuttingdiagram2d_summary_sheet.def.total_area * cutlist_group.def.std_thickness * _uv_to_inch3(volumic_mass[:unit], volumic_mass[:val]) unless volumic_mass[:val] == 0
            report_entry_sheet_def.total_cost = cuttingdiagram2d_summary_sheet.def.total_area * cutlist_group.def.std_thickness * _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cuttingdiagram2d_summary_sheet.def.width, cuttingdiagram2d_summary_sheet.def.length) unless std_price[:val] == 0
            report_entry_def.sheet_defs << report_entry_sheet_def

            report_entry_def.total_mass += report_entry_sheet_def.total_mass
            report_entry_def.total_cost += report_entry_sheet_def.total_cost

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count = report_group_def.total_count + report_entry_def.total_count
          report_group_def.total_area += report_entry_def.total_area

        when MaterialAttributes::TYPE_DIMENSIONAL

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.h_volumic_mass

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
          report_entry_def.errors += cuttingdiagram1d.errors
          report_entry_def.volumic_mass = volumic_mass
          report_entry_def.total_count = cuttingdiagram1d.summary.total_used_count
          report_entry_def.total_length = cuttingdiagram1d.summary.def.total_used_length

          cuttingdiagram1d.summary.bars.each do |cuttingdiagram1d_summary_bar|

            next unless cuttingdiagram1d_summary_bar.is_used

            std_price = _get_std_price([ Size2d.new(cutlist_group.def.std_dimension), cuttingdiagram1d_summary_bar.def.length ], material_attributes)

            report_entry_bar_def = DimensionalReportEntryBarDef.new(cuttingdiagram1d_summary_bar)
            report_entry_bar_def.std_price = std_price
            report_entry_bar_def.total_mass = cuttingdiagram1d_summary_bar.def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * _uv_to_inch3(volumic_mass[:unit], volumic_mass[:val]) unless volumic_mass[:val] == 0
            report_entry_bar_def.total_cost = cuttingdiagram1d_summary_bar.def.total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width, cuttingdiagram1d_summary_bar.def.length) unless std_price[:val] == 0
            report_entry_def.bar_defs << report_entry_bar_def

            report_entry_def.total_mass += report_entry_bar_def.total_mass
            report_entry_def.total_cost += report_entry_bar_def.total_cost

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count += report_entry_def.total_count
          report_group_def.total_length += report_entry_def.total_length

        when MaterialAttributes::TYPE_EDGE

          material_attributes = _get_material_attributes(cutlist_group.material_name)
          volumic_mass = material_attributes.h_volumic_mass
          std_price = _get_std_price([ cutlist_group.def.std_dimension.to_l ], material_attributes)

          report_entry_def = EdgeReportEntryDef.new(cutlist_group)
          report_entry_def.volumic_mass = volumic_mass
          report_entry_def.std_price = std_price
          report_entry_def.total_length = cutlist_group.def.total_cutting_length
          report_entry_def.total_mass = cutlist_group.def.total_cutting_volume * cutlist_group.def.std_thickness * cutlist_group.def.std_width * _uv_to_inch3(volumic_mass[:unit], volumic_mass[:val]) unless volumic_mass[:val] == 0
          report_entry_def.total_cost = cutlist_group.def.total_cutting_length * cutlist_group.def.std_thickness * cutlist_group.def.std_width * _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width) unless std_price[:val] == 0

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_length += report_entry_def.total_length

        when MaterialAttributes::TYPE_HARDWARE

          report_entry_def = HardwareReportEntryDef.new(cutlist_group)
          report_entry_def.total_count = cutlist_group.def.part_count

          cutlist_group.parts.each do |cutlist_part|

            if cutlist_part.is_a?(FolderPart)
              cutlist_part.children.each { |cutlist_child_part|
                _compute_hardware_part(cutlist_child_part, report_entry_def)
              }
            else
              _compute_hardware_part(cutlist_part, report_entry_def)
            end

          end

          report_group_def.entry_defs << report_entry_def
          report_group_def.total_count += report_entry_def.total_count

        end

        unless report_entry_def.nil?

          unless report_entry_def.errors.empty?
            @report_def.errors << [ 'tab.cutlist.report.error.entry_error', { :material_name => cutlist_group.material_display_name, :std_dimension => cutlist_group.std_dimension, :count => report_entry_def.errors.length } ]
          end

          report_group_def.total_mass += report_entry_def.total_mass
          report_group_def.total_cost += report_entry_def.total_cost

          @report_def.total_mass += report_entry_def.total_mass
          @report_def.total_cost += report_entry_def.total_cost

        end

      end

      if @starting || @remaining_step > 0
        response = {
            :remaining_step => @remaining_step,
        }
        @remaining_step = [ 0, @remaining_step - 1 ].max
        @starting = false
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

    def _compute_hardware_part(cutlist_part, report_entry_def)

      report_entry_part_def = HardwareReportEntryPartDef.new(cutlist_part)
      report_entry_def.part_defs << report_entry_part_def

      definition_attributes = _get_definition_attributes(cutlist_part.def.definition_id)

      h_mass = definition_attributes.h_mass
      unless h_mass[:val] == 0
        report_entry_part_def.mass = h_mass
        report_entry_part_def.total_mass = _uv_mass_to_model_unit(UnitUtils.split_unit(h_mass[:unit]).first, h_mass[:val]) * cutlist_part.def.count
        report_entry_def.total_mass = report_entry_def.total_mass + report_entry_part_def.total_mass
      end

      h_price = definition_attributes.h_price
      unless h_price[:val] == 0
        report_entry_part_def.price = h_price
        report_entry_part_def.total_cost = h_price[:val] * cutlist_part.def.count
        report_entry_def.total_cost = report_entry_def.total_cost + report_entry_part_def.total_cost
      end

    end

    def _get_std_price(entry_dim, material_attributes)

      h_std_prices = material_attributes.h_std_prices
      h_std_prices.each do |std_price|
        if std_price[:dim] == entry_dim
          return std_price
        end
      end

      h_std_prices[0]
    end

    def _uv_mass_to_model_unit(s_unit, f_value)

      case s_unit

      when MassUtils::UNIT_STRIPPEDNAME_KILOGRAM
        f_value = MassUtils.instance.kg_to_model_unit(f_value)
      when MassUtils::UNIT_STRIPPEDNAME_POUND
        f_value = MassUtils.instance.lb_to_model_unit(f_value)

      end

      f_value
    end

    def _uv_to_inch3(s_unit, f_value, inch_thickness = 0, inch_width = 0, inch_length = 0)

      return 0 if s_unit.nil?   # Invalid input

      unit_numerator, unit_denominator = s_unit.split('_')

      # Process mass if needed
      _uv_mass_to_model_unit(unit_numerator, f_value)

      # Process volume / area / length / instance or part
      case unit_denominator

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_3
        f_value = DimensionUtils.instance.m3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_3
        f_value = DimensionUtils.instance.ft3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_BOARD_FEET
        f_value = DimensionUtils.instance.fbm_to_inch3(f_value)

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.instance.m2_to_inch2(f_value) / inch_thickness
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.instance.ft2_to_inch2(f_value) / inch_thickness

      when DimensionUtils::UNIT_STRIPPEDNAME_METER
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.instance.m_to_inch(f_value) / inch_thickness / inch_width
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.instance.ft_to_inch(f_value) / inch_thickness / inch_width

      when 'i', 'p'
        f_value = inch_thickness * inch_width * inch_length == 0 ? 0 : f_value / inch_thickness / inch_width / inch_length

      end

      f_value
    end

  end

end
