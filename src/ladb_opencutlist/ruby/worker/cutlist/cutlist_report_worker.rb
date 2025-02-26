module Ladb::OpenCutList

  require_relative 'cutlist_cuttingdiagram1d_worker'
  require_relative 'cutlist_cuttingdiagram2d_worker'
  require_relative '../../model/report/report_def'
  require_relative '../../model/report/report_entry_def'
  require_relative '../../utils/hash_utils'
  require_relative '../../utils/dimension_utils'
  require_relative '../../helper/material_attributes_caching_helper'
  require_relative '../../helper/definition_attributes_caching_helper'
  require_relative '../../helper/estimation_helper'

  class CutlistReportWorker

    include MaterialAttributesCachingHelper
    include DefinitionAttributesCachingHelper
    include EstimationHelper

    def initialize(cutlist,

                   hidden_group_ids: [],
                   solid_wood_coefficient: 1.0

    )

      @cutlist = cutlist

      @hidden_group_ids = hidden_group_ids
      @solid_wood_coefficient = [ 1.0, DimensionUtils.str_to_ifloat(solid_wood_coefficient).to_l.to_f ].max

      @cutlist_groups = @cutlist.groups.select { |group| group.material_type != MaterialAttributes::TYPE_UNKNOWN && !@hidden_group_ids.include?(group.id) }
      @remaining_step = @cutlist_groups.count
      @starting = true

      @report_def = ReportDef.new
      @report_def.solid_wood_coefficient = @solid_wood_coefficient

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless Sketchup.active_model

      unless @starting || @cutlist_groups.count == 0

        cutlist_group = @cutlist_groups[@cutlist_groups.count - @remaining_step - 1]
        report_group_def = @report_def.group_defs[cutlist_group.material_type]
        report_entry_def = nil

        case cutlist_group.material_type

        when MaterialAttributes::TYPE_SOLID_WOOD

          report_entry_def = _compute_3d(cutlist_group, report_group_def, SolidWoodReportEntryDef.to_s, @solid_wood_coefficient)

        when MaterialAttributes::TYPE_SHEET_GOOD

          report_entry_def = _compute_2d(cutlist_group, report_group_def, SheetGoodReportEntryDef.to_s, SheetGoodReportEntrySheetDef.to_s)

        when MaterialAttributes::TYPE_DIMENSIONAL

          report_entry_def = _compute_1d(cutlist_group, report_group_def, DimensionalReportEntryDef.to_s, DimensionalReportEntryBarDef.to_s)

        when MaterialAttributes::TYPE_EDGE

          report_entry_def = _compute_1d(cutlist_group, report_group_def, EdgeReportEntryDef.to_s, EdgeReportEntryBarDef.to_s)

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
          report_group_def.total_instance_count += report_entry_def.total_instance_count
          report_group_def.total_used_instance_count += report_entry_def.total_used_instance_count

        when MaterialAttributes::TYPE_VENEER

          report_entry_def = _compute_2d(cutlist_group, report_group_def, VeneerReportEntryDef.to_s, VeneerReportEntrySheetDef.to_s)

        end

        unless report_entry_def.nil?

          unless report_entry_def.errors.empty?
            @report_def.errors << [ 'tab.cutlist.report.error.entry_error', { :material_name => cutlist_group.material_display_name, :std_dimension => cutlist_group.std_dimension, :count => report_entry_def.errors.length } ]
          end

          report_group_def.total_mass += report_entry_def.total_mass
          report_group_def.total_used_mass += report_entry_def.total_used_mass
          report_group_def.total_cost += report_entry_def.total_cost
          report_group_def.total_used_cost += report_entry_def.total_used_cost

          @report_def.total_mass += report_entry_def.total_mass
          @report_def.total_used_mass += report_entry_def.total_used_mass
          @report_def.total_cost += report_entry_def.total_cost
          @report_def.total_used_cost += report_entry_def.total_used_cost

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

        # Warnings
        if @hidden_group_ids.length > 0 && @hidden_group_ids.find_index('summary').nil? || @hidden_group_ids.length > 1 && !@hidden_group_ids.find_index('summary').nil?
          @report_def.warnings << 'tab.cutlist.report.warning.is_group_selection'
        end

        # Tips
        if @report_def.total_mass == 0 && @report_def.total_cost == 0
          @report_def.tips << 'tab.cutlist.report.tip.not_enough_data'
        end

        # Create the report
        report = @report_def.create_report

        response = report.to_hash

      end

      response
    end

    # -----

    private

    # -----

    def _compute_1d(cutlist_group, report_group_def, entry_def_class_name, item_def_class_name)

      material_attributes = _get_material_attributes(cutlist_group.material_name)

      return _compute_3d(cutlist_group, report_group_def, entry_def_class_name) unless material_attributes.raw_estimated

      settings = HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_cuttingdiagram1d_options', cutlist_group.id))
      settings[:group_id] = cutlist_group.id
      settings[:bar_folding] = false     # Remove unneeded computations
      settings[:hide_part_list] = true   # Remove unneeded computations
      settings[:part_drawing_type] = 0   # Remove unneeded computations

      std_sizes = material_attributes.std_lengths.split(';')
      if settings[:std_bar] == '' || settings[:std_sheet] != '0x0' && !std_sizes.include?(settings[:std_bar])
        settings[:std_bar] = std_sizes[0] unless std_sizes.empty?
      end

      worker = CutlistCuttingdiagram1dWorker.new(@cutlist, **settings)
      cuttingdiagram1d = worker.run

      report_entry_def = Object.const_get(entry_def_class_name).new(cutlist_group)
      report_entry_def.errors += cuttingdiagram1d.errors
      report_entry_def.raw_estimated = material_attributes.raw_estimated
      report_entry_def.total_count = cuttingdiagram1d.summary.total_used_count
      report_entry_def.total_length = cuttingdiagram1d.summary.def.total_used_length

      cuttingdiagram1d.bars.each do |cuttingdiagram1d_bar|

        # Only standard bar uses dim volumic mass and prices
        if cuttingdiagram1d_bar.type == BinPacking1D::BIN_TYPE_AUTO_GENERATED
          dim = material_attributes.compute_std_dim(cuttingdiagram1d_bar.def.length, cutlist_group.def.std_width, cutlist_group.def.std_thickness)
        else
          dim = nil
        end

        std_volumic_mass = _get_std_volumic_mass(dim, material_attributes)
        mass_per_inch3 = std_volumic_mass[:val] == 0 ? 0 : _uv_to_inch3(std_volumic_mass[:unit], std_volumic_mass[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width, cuttingdiagram1d_bar.def.length)

        std_price = _get_std_price(dim, material_attributes)
        price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width, cuttingdiagram1d_bar.def.length)

        report_entry_bar_def = report_entry_def.bar_defs[cuttingdiagram1d_bar.type_id]
        if report_entry_bar_def.nil?

          report_entry_bar_def = Object.const_get(item_def_class_name).new(cuttingdiagram1d_bar)
          report_entry_bar_def.std_volumic_mass = std_volumic_mass
          report_entry_bar_def.std_price = std_price

          report_entry_def.bar_defs[cuttingdiagram1d_bar.type_id] = report_entry_bar_def

        end

        total_length = cuttingdiagram1d_bar.def.length * cuttingdiagram1d_bar.def.count

        report_entry_bar_def.count += cuttingdiagram1d_bar.def.count
        report_entry_bar_def.total_length += total_length

        total_mass = total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * mass_per_inch3
        total_cost = total_length * cutlist_group.def.std_width * cutlist_group.def.std_thickness * price_per_inch3

        total_used_length = 0
        total_used_mass = 0
        total_used_cost = 0
        cuttingdiagram1d_bar.parts.each do |cuttingdiagram1d_part|
          part_def = cuttingdiagram1d_part.def.cutlist_part.def
          total_used_length += part_def.size.length * cuttingdiagram1d_bar.def.count
          total_used_mass += part_def.size.volume * mass_per_inch3 * cuttingdiagram1d_bar.def.count
          total_used_cost += part_def.size.volume * price_per_inch3 * cuttingdiagram1d_bar.def.count
        end

        report_entry_bar_def.total_used_length += total_used_length
        report_entry_bar_def.total_mass += total_mass
        report_entry_bar_def.total_used_mass += total_used_mass
        report_entry_bar_def.total_cost += total_cost
        report_entry_bar_def.total_used_cost += total_used_cost

        report_entry_def.total_used_length += total_used_length
        report_entry_def.total_mass += total_mass
        report_entry_def.total_used_mass += total_used_mass
        report_entry_def.total_cost += total_cost
        report_entry_def.total_used_cost += total_used_cost

      end

      report_group_def.entry_defs << report_entry_def
      report_group_def.total_count += report_entry_def.total_count
      report_group_def.total_length += report_entry_def.total_length
      report_group_def.total_used_length += report_entry_def.total_used_length

      report_entry_def
    end

    def _compute_2d(cutlist_group, report_group_def, entry_def_class_name, item_def_class_name)

      material_attributes = _get_material_attributes(cutlist_group.material_name)

      return _compute_3d(cutlist_group, report_group_def, entry_def_class_name) unless material_attributes.raw_estimated

      settings = HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_cuttingdiagram2d_options', cutlist_group.id))
      settings[:group_id] = cutlist_group.id
      settings[:sheet_folding] = false   # Remove unneeded computations
      settings[:hide_part_list] = true   # Remove unneeded computations
      settings[:part_drawing_type] = 0   # Remove unneeded computations

      std_sizes = material_attributes.std_sizes.split(';')
      if settings[:std_sheet] == '' || settings[:std_sheet] != '0x0' && !std_sizes.include?(settings[:std_sheet])
        settings[:std_sheet] = std_sizes[0] unless std_sizes.empty?
      end

      worker = CutlistCuttingdiagram2dWorker.new(@cutlist, **settings)
      cuttingdiagram2d = worker.run

      report_entry_def = Object.const_get(entry_def_class_name).new(cutlist_group)
      report_entry_def.errors += cuttingdiagram2d.errors
      report_entry_def.raw_estimated = material_attributes.raw_estimated
      report_entry_def.total_count = cuttingdiagram2d.summary.total_used_count
      report_entry_def.total_area = cuttingdiagram2d.summary.def.total_used_area

      cuttingdiagram2d.sheets.each do |cuttingdiagram2d_sheet|

        # Only standard sheet uses dim volumic mass and prices
        if cuttingdiagram2d_sheet.type == BinPacking2D::BIN_TYPE_AUTO_GENERATED
          dim = material_attributes.compute_std_dim(cuttingdiagram2d_sheet.def.length, cuttingdiagram2d_sheet.def.width, cutlist_group.def.std_thickness)
        else
          dim = nil
        end

        std_volumic_mass = _get_std_volumic_mass(dim, material_attributes)
        mass_per_inch3 = std_volumic_mass[:val] == 0 ? 0 : _uv_to_inch3(std_volumic_mass[:unit], std_volumic_mass[:val], cutlist_group.def.std_thickness, cuttingdiagram2d_sheet.def.width, cuttingdiagram2d_sheet.def.length)

        std_price = _get_std_price(dim, material_attributes)
        price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cuttingdiagram2d_sheet.def.width, cuttingdiagram2d_sheet.def.length)

        report_entry_sheet_def = report_entry_def.sheet_defs[cuttingdiagram2d_sheet.type_id]
        if report_entry_sheet_def.nil?

          report_entry_sheet_def = Object.const_get(item_def_class_name).new(cuttingdiagram2d_sheet)
          report_entry_sheet_def.std_volumic_mass = std_volumic_mass
          report_entry_sheet_def.std_price = std_price

          report_entry_def.sheet_defs[cuttingdiagram2d_sheet.type_id] = report_entry_sheet_def

        end

        total_area = cuttingdiagram2d_sheet.def.length * cuttingdiagram2d_sheet.def.width * cuttingdiagram2d_sheet.def.count

        report_entry_sheet_def.count += cuttingdiagram2d_sheet.def.count
        report_entry_sheet_def.total_area += total_area

        total_mass = total_area * cutlist_group.def.std_thickness * mass_per_inch3
        total_cost = total_area * cutlist_group.def.std_thickness * price_per_inch3

        total_used_area = 0
        total_used_mass = 0
        total_used_cost = 0
        cuttingdiagram2d_sheet.parts.each do |cuttingdiagram2d_part|
          part_def = cuttingdiagram2d_part.def.cutlist_part.def
          total_used_area += part_def.size.area * cuttingdiagram2d_sheet.def.count
          total_used_mass += part_def.size.volume * mass_per_inch3 * cuttingdiagram2d_sheet.def.count
          total_used_cost += part_def.size.volume * price_per_inch3 * cuttingdiagram2d_sheet.def.count
        end

        report_entry_sheet_def.total_used_area += total_used_area
        report_entry_sheet_def.total_mass += total_mass
        report_entry_sheet_def.total_used_mass += total_used_mass
        report_entry_sheet_def.total_cost += total_cost
        report_entry_sheet_def.total_used_cost += total_used_cost

        report_entry_def.total_used_area += total_used_area
        report_entry_def.total_mass += total_mass
        report_entry_def.total_used_mass += total_used_mass
        report_entry_def.total_cost += total_cost
        report_entry_def.total_used_cost += total_used_cost

      end

      report_group_def.entry_defs << report_entry_def
      report_group_def.total_count += report_entry_def.total_count
      report_group_def.total_area += report_entry_def.total_area
      report_group_def.total_used_area += report_entry_def.total_used_area

      report_entry_def
    end

    def _compute_3d(cutlist_group, report_group_def, entry_def_class_name, coefficient = 1.0)

      material_attributes = _get_material_attributes(cutlist_group.material_name)

      dim = material_attributes.compute_std_dim(0, cutlist_group.def.std_width, cutlist_group.def.std_thickness)

      std_volumic_mass = _get_std_volumic_mass(dim, material_attributes)
      mass_per_inch3 = std_volumic_mass[:val] == 0 ? 0 : _uv_to_inch3(std_volumic_mass[:unit], std_volumic_mass[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width)

      std_price = _get_std_price(dim, material_attributes)
      price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], cutlist_group.def.std_thickness, cutlist_group.def.std_width)

      report_entry_def = Object.const_get(entry_def_class_name).new(cutlist_group)
      report_entry_def.raw_estimated = material_attributes.raw_estimated
      report_entry_def.std_volumic_mass = std_volumic_mass if report_entry_def.respond_to?(:std_volumic_mass)
      report_entry_def.std_price = std_price if report_entry_def.respond_to?(:std_price=)
      report_entry_def.total_volume = cutlist_group.def.total_cutting_volume * coefficient if report_entry_def.respond_to?(:total_volume=)
      report_entry_def.total_area = cutlist_group.def.total_cutting_area * coefficient if report_entry_def.respond_to?(:total_area=)
      report_entry_def.total_length = cutlist_group.def.total_cutting_length * coefficient if report_entry_def.respond_to?(:total_length=)
      report_entry_def.total_mass = cutlist_group.def.total_cutting_volume * coefficient * mass_per_inch3
      report_entry_def.total_cost = cutlist_group.def.total_cutting_volume * coefficient * price_per_inch3

      # Compute parts volume, area, length, mass and cost
      cutlist_group.def.part_defs.each do |id, part_def|
        report_entry_def.total_used_volume += part_def.size.volume * part_def.count if report_entry_def.respond_to?(:total_used_volume=)
        report_entry_def.total_used_area += part_def.size.area * part_def.count if report_entry_def.respond_to?(:total_used_area=)
        report_entry_def.total_used_length += part_def.size.length * part_def.count if report_entry_def.respond_to?(:total_used_length=)
        report_entry_def.total_used_mass += part_def.size.volume * part_def.count * mass_per_inch3
        report_entry_def.total_used_cost += part_def.size.volume * part_def.count * price_per_inch3
      end

      report_group_def.entry_defs << report_entry_def
      report_group_def.total_volume += report_entry_def.total_volume if report_group_def.respond_to?(:total_volume=)
      report_group_def.total_used_volume += report_entry_def.total_used_volume if report_group_def.respond_to?(:total_used_volume=)
      report_group_def.total_area += report_entry_def.total_area if report_group_def.respond_to?(:total_area=)
      report_group_def.total_used_area += report_entry_def.total_used_area if report_group_def.respond_to?(:total_used_area=)
      report_group_def.total_length += report_entry_def.total_length if report_group_def.respond_to?(:total_length=)
      report_group_def.total_used_length += report_entry_def.total_used_length if report_group_def.respond_to?(:total_used_length=)

      report_entry_def
    end

    def _compute_hardware_part(cutlist_part, report_entry_def)

      report_entry_part_def = HardwareReportEntryPartDef.new(cutlist_part)
      report_entry_def.part_defs << report_entry_part_def

      definition_attributes = _get_definition_attributes(cutlist_part.def.definition_id)

      total_instance_count = cutlist_part.def.instance_count_by_part * cutlist_part.def.count
      total_used_instance_count = cutlist_part.def.instance_count_by_part * cutlist_part.def.count - cutlist_part.def.unused_instance_count
      used_ratio = total_used_instance_count.to_f / total_instance_count.to_f

      report_entry_part_def.total_instance_count = total_instance_count
      report_entry_part_def.total_used_instance_count = total_used_instance_count

      report_entry_def.total_instance_count += total_instance_count
      report_entry_def.total_used_instance_count += total_used_instance_count

      h_mass = definition_attributes.h_mass
      unless h_mass[:val] == 0

        report_entry_part_def.mass = h_mass

        total_mass = _uv_mass_to_model_unit(UnitUtils.split_unit(h_mass[:unit]).first, h_mass[:val]) * cutlist_part.def.count
        total_used_mass = total_mass * used_ratio

        report_entry_part_def.total_mass = total_mass
        report_entry_part_def.total_used_mass = total_used_mass

        report_entry_def.total_mass += total_mass
        report_entry_def.total_used_mass += total_used_mass

      end

      h_price = definition_attributes.h_price
      unless h_price[:val] == 0

        report_entry_part_def.price = h_price

        total_cost = h_price[:val] * cutlist_part.def.count
        total_used_cost = total_cost * used_ratio

        report_entry_part_def.total_cost = total_cost
        report_entry_part_def.total_used_cost = total_used_cost

        report_entry_def.total_cost += total_cost
        report_entry_def.total_used_cost += total_used_cost

      end

    end

  end

end
