module Ladb::OpenCutList

  require_relative '../../helper/material_attributes_caching_helper'
  require_relative '../../helper/definition_attributes_caching_helper'
  require_relative '../../helper/estimation_helper'
  require_relative '../../model/attributes/material_attributes'
  require_relative '../../model/estimate/estimate_def'
  require_relative '../../model/estimate/estimate_entry_def'
  require_relative '../../utils/unit_utils'
  require_relative 'cutlist_packing_worker'

  class CutlistEstimateWorker

    include MaterialAttributesCachingHelper
    include DefinitionAttributesCachingHelper

    attr_reader :cutlist, :estimate_def

    def initialize(cutlist,

                   part_ids: nil,

                   hidden_group_ids: []   # Unused locally, but necessary for UI

    )

      @cutlist = cutlist

      @part_ids = part_ids

      @estimate_def = EstimateDef.new

      # Internals

      @runs = []
      @run_index = 0

      @cancelled = false

    end

    # -----

    def run(action = :start)
      case action

      when :start

        return { :errors => [ 'default.error' ] } unless @cutlist
        return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

        model = Sketchup.active_model
        return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

        parts = @cutlist.get_parts(@part_ids)
        return { :errors => [ 'tab.cutlist.error.no_part' ] } if parts.empty?

        @parts_by_group = parts.group_by { |part| part.group }

        # Create runs
        @parts_by_group.each do |group, parts|
          next if group.material_type == MaterialAttributes::TYPE_UNKNOWN
          @runs << _create_run(group, parts.map { |part| part.id })
        end

        return {
          steps: @runs.length,
          running: true
        }

      when :advance
        return {
          cancelled: true
        } if @cancelled

        # Process current run
        solution = nil
        unless (run = @runs[@run_index]).nil?
          if run.finished?

            # Jump to the next run
            @run_index += 1
            run = @runs[@run_index]

          end
        end
        unless run.nil?
          if !run.started?

            run.start
            solution = 'none' # Clear solution preview

          else

            result = run.advance
            solution = result['solution'] unless result.nil?

          end
        end

        return {
          running: true,
          run_index: @run_index,
          run_progress: run.progress,
          run_name: run.name,
          solution: solution,
        } unless run.nil?

        # COMPLETED

        # Errors
        if @estimate_def.group_defs.values.select { |group_def| !group_def.entry_defs.empty? }.length == 0
          @estimate_def.errors << 'tab.cutlist.estimate.error.no_typed_material_parts'
        end

        # Warnings
        if @parts_by_group.keys.one? && @parts_by_group.keys.first.parts.length != @parts_by_group.values.first.length
          @estimate_def.warnings << 'tab.cutlist.estimate.warning.is_part_selection'
        end

        # Tips
        if @estimate_def.total_mass == 0 && @estimate_def.total_cost == 0
          @estimate_def.tips << 'tab.cutlist.estimate.tip.not_enough_data'
        end

        # Create the estimate
        estimate = @estimate_def.create_estimate

        return estimate.to_hash

      when :next

        # Cancel current run
        unless (run = @runs[@run_index]).nil?
          run.cancel
        end

        return {}

      when :cancel
        @cancelled = true

        # Cancel current run
        unless (run = @runs[@run_index]).nil?
          run.cancel
        end

        return {}

      end
      {}
    end

    # -----

    private

    def _create_run(cutlist_group, part_ids = nil)

      material_attributes = _get_material_attributes(cutlist_group.material_name)

      case material_attributes.type

      when MaterialAttributes::TYPE_SOLID_WOOD
        return Estimate3dRun.new(self, cutlist_group, part_ids, material_attributes, SolidWoodEstimateEntryDef)

      when MaterialAttributes::TYPE_SHEET_GOOD
        return Estimate3dRun.new(self, cutlist_group, part_ids, material_attributes, SheetGoodEstimateEntryDef, SheetGoodEstimateEntryBinDef) unless material_attributes.raw_estimated
        return Estimate2dRun.new(self, cutlist_group, part_ids, material_attributes, SheetGoodEstimateEntryDef, SheetGoodEstimateEntryBinDef)

      when MaterialAttributes::TYPE_DIMENSIONAL
        return Estimate3dRun.new(self, cutlist_group, part_ids, material_attributes, DimensionalEstimateEntryDef, DimensionalEstimateEntryBarDef) unless material_attributes.raw_estimated
        return Estimate1dRun.new(self, cutlist_group, part_ids, material_attributes, DimensionalEstimateEntryDef, DimensionalEstimateEntryBarDef)

      when MaterialAttributes::TYPE_EDGE
        return Estimate3dRun.new(self, cutlist_group, part_ids, material_attributes, EdgeEstimateEntryDef, EdgeEstimateEntryBarDef) unless material_attributes.raw_estimated
        return Estimate1dRun.new(self, cutlist_group, part_ids, material_attributes, EdgeEstimateEntryDef, EdgeEstimateEntryBarDef)

      when MaterialAttributes::TYPE_VENEER
        return Estimate3dRun.new(self, cutlist_group, part_ids, material_attributes, VeneerEstimateEntryDef, VeneerEstimateEntryBinDef) unless material_attributes.raw_estimated
        return Estimate2dRun.new(self, cutlist_group, part_ids, material_attributes, VeneerEstimateEntryDef, VeneerEstimateEntryBinDef)

      when MaterialAttributes::TYPE_HARDWARE
        return EstimateHardwareRun.new(self, cutlist_group, part_ids, material_attributes, HardwareEstimateEntryDef, HardwareEstimateEntryPartDef)

      end

    end

  end

  # -----

  class AbstractEstimateRun

    include EstimationHelper

    def initialize(worker, cutlist_group, part_ids, material_attributes, entry_def_class, item_def_class = nil)

      @worker = worker
      @cutlist_group = cutlist_group
      @part_ids = part_ids
      @material_attributes = material_attributes
      @entry_def_class = entry_def_class
      @item_def_class = item_def_class

      @name = "#{cutlist_group.material_name}#{" / #{cutlist_group.std_dimension}" unless cutlist_group.std_dimension.empty?}"
      @progress = 0.0
      @started = false
      @finished = false

    end

    def start
      @started = true
    end

    def advance
    end

    def cancel
    end

    # -----

    def name
      @name
    end

    def progress
      @progress
    end

    def started?
      @started
    end

    def finished?
      @finished
    end

    protected

    def _finalize

      @progress = 1.0
      @finished = true

      _create_entry_defs.each do |estimate_entry_def|

        if estimate_entry_def.respond_to?(:errors) && estimate_entry_def.errors.any?
          @worker.estimate_def.errors << [ 'tab.cutlist.estimate.error.entry_error', { :material_name => @cutlist_group.material_display_name, :std_dimension => @cutlist_group.std_dimension, :count => estimate_entry_def.errors.length } ]
        end

        estimate_group_def = estimate_entry_def.parent_def
        if estimate_group_def.is_a?(AbstractEstimateWeightedGroupDef)
          estimate_group_def.total_mass += estimate_entry_def.total_mass if estimate_entry_def.respond_to?(:total_mass)
          estimate_group_def.total_used_mass += estimate_entry_def.total_used_mass if estimate_entry_def.respond_to?(:total_used_mass)
        end
        if estimate_group_def.is_a?(AbstractEstimateGroupDef)
          estimate_group_def.total_cost += estimate_entry_def.total_cost
          estimate_group_def.total_used_cost += estimate_entry_def.total_used_cost
        end

        @worker.estimate_def.total_mass += estimate_entry_def.total_mass if estimate_entry_def.respond_to?(:total_mass)
        @worker.estimate_def.total_used_mass += estimate_entry_def.total_used_mass if estimate_entry_def.respond_to?(:total_used_mass)
        @worker.estimate_def.total_cost += estimate_entry_def.total_cost
        @worker.estimate_def.total_used_cost += estimate_entry_def.total_used_cost

      end

    end

    def _get_group_def
      @worker.estimate_def.group_defs[@cutlist_group.material_type]
    end

    def _create_entry_defs
      []
    end

  end

  class AbstractEstimatePackingRun < AbstractEstimateRun

    def initialize(worker, cutlist_group, part_ids, material_attributes, entry_def_class, item_def_class = nil)
      super

      @packing_worker = nil
      @packing = nil

    end

    def start
      super

      settings = HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_packing_options', @cutlist_group.id))
      settings[:part_ids] = @part_ids

      _ensure_default_settings(settings)

      @time_limit = settings[:time_limit].to_f
      @start_time = Time.new

      @packing_worker = CutlistPackingWorker.new(@worker.cutlist, **settings)
      @packing = @packing_worker.run

      _finalize unless @packing.running

      @packing.to_hash
    end

    def advance
      super
      unless finished? || @packing_worker.nil?

        @packing = @packing_worker.run(:advance)
        @progress = [ (Time.new - @start_time) / @time_limit, 1.0 ].min

        _finalize unless @packing.running

        return @packing.to_hash
      end
      nil
    end

    def cancel
      super
      unless finished? || @packing_worker.nil?

        packing = @packing_worker.run(:cancel)

        return packing.to_hash
      end
      nil
    end

    # ----

    protected

    def _ensure_default_settings(settings)
      settings[:verbosity_level] = 0
    end

    def _create_entry_defs

      cut_group_def = @worker.estimate_def.group_defs[-1]
      cut_entry_def = nil

      estimate_group_def = _get_group_def

      estimate_entry_def = @entry_def_class.new(estimate_group_def, @cutlist_group)
      estimate_entry_def.errors += @packing.errors
      estimate_entry_def.raw_estimated = @material_attributes.raw_estimated

      unless @packing.solution.nil?

        estimate_entry_def.total_count = @packing.solution.summary.def.total_used_count
        estimate_entry_def.total_length = @packing.solution.summary.def.total_used_length if estimate_entry_def.respond_to?(:total_length=)
        estimate_entry_def.total_area = @packing.solution.summary.def.total_used_area if estimate_entry_def.respond_to?(:total_area=)

        @packing.solution.bins.each do |packing_bin|

          bin_type_def = packing_bin.def.bin_type_def

          dim = @material_attributes.compute_std_dim(bin_type_def.length, bin_type_def.width, @cutlist_group.def.std_thickness)

          std_volumic_mass = _get_std_volumic_mass(dim, @material_attributes)
          mass_per_inch3 = std_volumic_mass[:val] == 0 ? 0 : _uv_to_inch3(std_volumic_mass[:unit], std_volumic_mass[:val], @cutlist_group.def.std_thickness, bin_type_def.width, bin_type_def.length)

          std_price = _get_std_price(dim, @material_attributes)
          price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], @cutlist_group.def.std_thickness, bin_type_def.width, bin_type_def.length)

          estimate_entry_bin_def = estimate_entry_def.bin_defs[bin_type_def.id]
          if estimate_entry_bin_def.nil?

            estimate_entry_bin_def = @item_def_class.new(estimate_entry_def, bin_type_def)
            estimate_entry_bin_def.std_volumic_mass = std_volumic_mass
            estimate_entry_bin_def.std_price = std_price

            estimate_entry_def.bin_defs[bin_type_def.id] = estimate_entry_bin_def

          end

          total_length = bin_type_def.length * packing_bin.def.count
          total_area = bin_type_def.length * bin_type_def.width * packing_bin.def.count

          estimate_entry_bin_def.count += packing_bin.def.count
          estimate_entry_bin_def.total_length += total_length if estimate_entry_bin_def.respond_to?(:total_length=)
          estimate_entry_bin_def.total_area += total_area if estimate_entry_bin_def.respond_to?(:total_area=)

          total_mass = total_area * @cutlist_group.def.std_thickness * mass_per_inch3
          total_cost = total_area * @cutlist_group.def.std_thickness * price_per_inch3

          total_used_length = 0
          total_used_area = 0
          total_used_mass = 0
          total_used_cost = 0
          packing_bin.items.each do |packing_item|
            item_type_def = packing_item.def.item_type_def
            part_def = item_type_def.part.def
            total_used_length += part_def.size.length * packing_bin.def.count
            total_used_area += part_def.size.area * packing_bin.def.count
            total_used_mass += part_def.size.volume * mass_per_inch3 * packing_bin.def.count
            total_used_cost += part_def.size.volume * price_per_inch3 * packing_bin.def.count
          end

          estimate_entry_bin_def.total_used_length += total_used_length if estimate_entry_bin_def.respond_to?(:total_used_length=)
          estimate_entry_bin_def.total_used_area += total_used_area if estimate_entry_bin_def.respond_to?(:total_used_area=)
          estimate_entry_bin_def.total_mass += total_mass
          estimate_entry_bin_def.total_used_mass += total_used_mass
          estimate_entry_bin_def.total_cost += total_cost
          estimate_entry_bin_def.total_used_cost += total_used_cost

          estimate_entry_def.total_used_length += total_used_length if estimate_entry_def.respond_to?(:total_used_length=)
          estimate_entry_def.total_used_area += total_used_area if estimate_entry_def.respond_to?(:total_used_area=)
          estimate_entry_def.total_mass += total_mass
          estimate_entry_def.total_used_mass += total_used_mass
          estimate_entry_def.total_cost += total_cost
          estimate_entry_def.total_used_cost += total_used_cost

          # Cuts

          if packing_bin.def.cut_length > 0

            std_cut_price = _get_std_cut_price(dim, @material_attributes)
            price_per_inch = std_cut_price[:val] == 0 ? 0 : _uv_to_inch(std_cut_price[:unit], std_cut_price[:val], packing_bin.def.number_of_cuts ? packing_bin.def.cut_length / packing_bin.def.number_of_cuts : 0)

            if cut_entry_def.nil?

              cut_entry_def = CutEstimateEntryDef.new(cut_group_def, @cutlist_group)

            end

            cut_entry_bin_def = cut_entry_def.bin_defs[bin_type_def.id]
            if cut_entry_bin_def.nil?

              cut_entry_bin_def = CutEstimateEntryBinDef.new(cut_entry_def, bin_type_def)
              cut_entry_bin_def.std_price = std_cut_price

              cut_entry_def.bin_defs[bin_type_def.id] = cut_entry_bin_def

            end

            total_count = packing_bin.def.number_of_cuts * packing_bin.def.count
            total_length = packing_bin.def.cut_length * packing_bin.def.count
            total_cost = packing_bin.def.cut_length * price_per_inch * packing_bin.def.count

            cut_entry_bin_def.count += total_count
            cut_entry_bin_def.total_length += total_length
            cut_entry_bin_def.total_cost += total_cost
            cut_entry_bin_def.total_used_cost += total_cost

            cut_entry_def.total_count += total_count
            cut_entry_def.total_length += total_length
            cut_entry_def.total_cost += total_cost
            cut_entry_def.total_used_cost += total_cost

          end

        end

      end

      estimate_group_def.entry_defs << estimate_entry_def
      estimate_group_def.total_count += estimate_entry_def.total_count
      estimate_group_def.total_length += estimate_entry_def.total_length if estimate_group_def.respond_to?(:total_length=)
      estimate_group_def.total_used_length += estimate_entry_def.total_used_length if estimate_group_def.respond_to?(:total_used_length=)
      estimate_group_def.total_area += estimate_entry_def.total_area if estimate_group_def.respond_to?(:total_area=)
      estimate_group_def.total_used_area += estimate_entry_def.total_used_area if estimate_group_def.respond_to?(:total_used_area=)

      # Add cut entry only if it has cost
      if !cut_entry_def.nil? && cut_entry_def.total_cost > 0

        cut_group_def.entry_defs << cut_entry_def

        cut_group_def.total_count += cut_entry_def.total_count
        cut_group_def.total_length += cut_entry_def.total_length

      else
        cut_entry_def = nil
      end

      [ estimate_entry_def, cut_entry_def ].compact
    end

  end

  class Estimate1dRun < AbstractEstimatePackingRun

    protected

    def _ensure_default_settings(settings)
      super

      std_lengths = DimensionUtils.d_to_ifloats(@material_attributes.std_lengths).split(DimensionUtils::LIST_SEPARATOR)
      std_bin_1d_sizes = DimensionUtils.d_to_ifloats(settings[:std_bin_1d_sizes]).split(DimensionUtils::LIST_SEPARATOR)

      if settings[:std_bin_1d_sizes].to_s.strip != '0' # Not 'None'
        settings[:std_bin_1d_sizes] = (std_lengths & std_bin_1d_sizes).join(DimensionUtils::LIST_SEPARATOR)
      end
      if settings[:std_bin_1d_sizes].to_s.strip.empty?
        settings[:std_bin_1d_sizes] = std_lengths[0].to_s unless std_lengths.empty?
      end

      if settings[:problem_type] == Packy::PROBLEM_TYPE_RECTANGLEGUILLOTINE ||
         settings[:problem_type] == Packy::PROBLEM_TYPE_RECTANGLE
        settings[:problem_type] = Packy::PROBLEM_TYPE_ONEDIMENSIONAL
      end

    end

  end

  class Estimate2dRun < AbstractEstimatePackingRun

    protected

    def _ensure_default_settings(settings)
      super

      std_sizes = DimensionUtils.dxd_to_ifloats(@material_attributes.std_sizes).split(DimensionUtils::LIST_SEPARATOR)
      std_bin_2d_sizes = DimensionUtils.dxd_to_ifloats(settings[:std_bin_2d_sizes]).split(DimensionUtils::LIST_SEPARATOR)

      if settings[:std_bin_2d_sizes].to_s.strip.match(/^0+\s*x\s*0+$/).nil? # Not 'None'
        settings[:std_bin_2d_sizes] = (std_sizes & std_bin_2d_sizes).join(DimensionUtils::LIST_SEPARATOR)
      end
      if settings[:std_bin_2d_sizes].to_s.strip.empty?
        settings[:std_bin_2d_sizes] = std_sizes[0].to_s unless std_sizes.empty?
      end

    end

  end

  class Estimate3dRun < AbstractEstimateRun

    def start
      super
      _finalize
    end

    protected

    def _create_entry_defs

      dim = @material_attributes.compute_std_dim(0, @cutlist_group.def.std_width, @cutlist_group.def.std_thickness)

      std_volumic_mass = _get_std_volumic_mass(dim, @material_attributes)
      mass_per_inch3 = std_volumic_mass[:val] == 0 ? 0 : _uv_to_inch3(std_volumic_mass[:unit], std_volumic_mass[:val], @cutlist_group.def.std_thickness, @cutlist_group.def.std_width)

      std_price = _get_std_price(dim, @material_attributes)
      price_per_inch3 = std_price[:val] == 0 ? 0 : _uv_to_inch3(std_price[:unit], std_price[:val], @cutlist_group.def.std_thickness, @cutlist_group.def.std_width)

      estimate_group_def = _get_group_def

      estimate_entry_def = @entry_def_class.new(estimate_group_def, @cutlist_group)
      estimate_entry_def.raw_estimated = @material_attributes.raw_estimated
      estimate_entry_def.multiplier_coefficient = @material_attributes.multiplier_coefficient
      estimate_entry_def.std_volumic_mass = std_volumic_mass if estimate_entry_def.respond_to?(:std_volumic_mass)
      estimate_entry_def.std_price = std_price if estimate_entry_def.respond_to?(:std_price=)
      estimate_entry_def.total_volume = @cutlist_group.def.total_cutting_volume * @material_attributes.multiplier_coefficient if estimate_entry_def.respond_to?(:total_volume=)
      estimate_entry_def.total_area = @cutlist_group.def.total_cutting_area * @material_attributes.multiplier_coefficient if estimate_entry_def.respond_to?(:total_area=)
      estimate_entry_def.total_length = @cutlist_group.def.total_cutting_length * @material_attributes.multiplier_coefficient if estimate_entry_def.respond_to?(:total_length=)
      estimate_entry_def.total_mass = @cutlist_group.def.total_cutting_volume * @material_attributes.multiplier_coefficient * mass_per_inch3
      estimate_entry_def.total_cost = @cutlist_group.def.total_cutting_volume * @material_attributes.multiplier_coefficient * price_per_inch3

      # Compute parts volume, area, length, mass and cost
      @cutlist_group.def.part_defs.each do |id, part_def|
        estimate_entry_def.total_used_volume += part_def.size.volume * part_def.count if estimate_entry_def.respond_to?(:total_used_volume=)
        estimate_entry_def.total_used_area += part_def.size.area * part_def.count if estimate_entry_def.respond_to?(:total_used_area=)
        estimate_entry_def.total_used_length += part_def.size.length * part_def.count if estimate_entry_def.respond_to?(:total_used_length=)
        estimate_entry_def.total_used_mass += part_def.size.volume * part_def.count * mass_per_inch3
        estimate_entry_def.total_used_cost += part_def.size.volume * part_def.count * price_per_inch3
      end

      estimate_group_def.entry_defs << estimate_entry_def
      estimate_group_def.total_volume += estimate_entry_def.total_volume if estimate_group_def.respond_to?(:total_volume=)
      estimate_group_def.total_used_volume += estimate_entry_def.total_used_volume if estimate_group_def.respond_to?(:total_used_volume=)
      estimate_group_def.total_area += estimate_entry_def.total_area if estimate_group_def.respond_to?(:total_area=)
      estimate_group_def.total_used_area += estimate_entry_def.total_used_area if estimate_group_def.respond_to?(:total_used_area=)
      estimate_group_def.total_length += estimate_entry_def.total_length if estimate_group_def.respond_to?(:total_length=)
      estimate_group_def.total_used_length += estimate_entry_def.total_used_length if estimate_group_def.respond_to?(:total_used_length=)

      [ estimate_entry_def ]
    end

  end

  class EstimateHardwareRun < AbstractEstimateRun

    def start
      super
      _finalize
    end

    protected

    def _create_entry_defs

      estimate_group_def = _get_group_def

      estimate_entry_def = @entry_def_class.new(estimate_group_def, @cutlist_group)
      estimate_entry_def.total_count = @cutlist_group.def.part_count

      fn_compute_hardware_part = lambda do |cutlist_part, estimate_entry_def|

        estimate_entry_part_def = @item_def_class.new(estimate_entry_def, cutlist_part)
        estimate_entry_def.part_defs << estimate_entry_part_def

        definition_attributes = @worker._get_definition_attributes(cutlist_part.def.definition_id)

        total_instance_count = cutlist_part.def.instance_count_by_part * cutlist_part.def.count
        total_used_instance_count = cutlist_part.def.instance_count_by_part * cutlist_part.def.count - cutlist_part.def.unused_instance_count
        used_ratio = total_used_instance_count.to_f / total_instance_count.to_f

        estimate_entry_part_def.total_instance_count = total_instance_count
        estimate_entry_part_def.total_used_instance_count = total_used_instance_count

        estimate_entry_def.total_instance_count += total_instance_count
        estimate_entry_def.total_used_instance_count += total_used_instance_count

        h_mass = definition_attributes.h_mass
        unless h_mass[:val] == 0

          estimate_entry_part_def.mass = h_mass

          total_mass = _uv_mass_to_model_unit(UnitUtils.split_unit(h_mass[:unit]).first, h_mass[:val]) * cutlist_part.def.count
          total_used_mass = total_mass * used_ratio

          estimate_entry_part_def.total_mass = total_mass
          estimate_entry_part_def.total_used_mass = total_used_mass

          estimate_entry_def.total_mass += total_mass
          estimate_entry_def.total_used_mass += total_used_mass

        end

        h_price = definition_attributes.h_price
        unless h_price[:val] == 0

          estimate_entry_part_def.price = h_price

          total_cost = h_price[:val] * cutlist_part.def.count
          total_used_cost = total_cost * used_ratio

          estimate_entry_part_def.total_cost = total_cost
          estimate_entry_part_def.total_used_cost = total_used_cost

          estimate_entry_def.total_cost += total_cost
          estimate_entry_def.total_used_cost += total_used_cost

        end

      end

      @cutlist_group.parts.each do |cutlist_part|

        if cutlist_part.is_a?(FolderPart)
          cutlist_part.children.each { |cutlist_child_part|
            fn_compute_hardware_part.call(cutlist_child_part, estimate_entry_def)
          }
        else
          fn_compute_hardware_part.call(cutlist_part, estimate_entry_def)
        end

      end

      estimate_group_def.entry_defs << estimate_entry_def
      estimate_group_def.total_count += estimate_entry_def.total_count
      estimate_group_def.total_instance_count += estimate_entry_def.total_instance_count
      estimate_group_def.total_used_instance_count += estimate_entry_def.total_used_instance_count

      [ estimate_entry_def ]
    end

  end

end