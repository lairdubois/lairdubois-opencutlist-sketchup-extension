module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'

  class Estimate < DataContainer

    include HashableHelper

    attr_reader :errors, :warnings, :tips, :total_mass, :total_used_mass, :total_unused_mass, :total_unused_mass_ratio, :total_cost, :total_used_cost, :total_unused_cost, :total_unused_cost_ratio, :groups

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @total_mass = _def.total_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_mass)
      @total_used_mass = _def.total_used_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_used_mass)
      @total_unused_mass = _def.total_unused_mass == 0 ? nil : MassUtils.format_to_readable_mass(_def.total_unused_mass)
      @total_unused_mass_ratio = _def.total_unused_mass == 0 ? nil : _def.total_unused_mass / _def.total_mass

      @total_cost = _def.total_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_cost)
      @total_used_cost = _def.total_used_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_used_cost)
      @total_unused_cost = _def.total_unused_cost == 0 ? nil : PriceUtils.format_to_readable_price(_def.total_unused_cost)
      @total_unused_cost_ratio = _def.total_unused_cost == 0 ? nil : _def.total_unused_cost / _def.total_cost

      @groups = _def.group_defs.values.select { |group_def| !group_def.entry_defs.empty? }.map { |group_def|
        group = group_def.create_group
        group.mass_ratio = _def.total_mass == 0 ? nil : group_def.total_mass / _def.total_mass if group_def.is_a?(AbstractEstimateWeightedGroupDef)
        group.cost_ratio = _def.total_cost == 0 ? nil : group_def.total_cost / _def.total_cost
        group
      }

    end

  end

end
