module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Report

    include HashableHelper

    attr_reader :errors, :warnings, :tips, :total_mass, :total_cost, :groups

    def initialize(_def)
      @_def = _def

      @errors = _def.errors
      @warnings = _def.warnings
      @tips = _def.tips

      @total_mass = _def.total_mass
      @total_cost = _def.total_cost

      @groups = _def.group_defs.values.select { |group_def| !group_def.entry_defs.empty? }.map { |group_def| group_def.create_group }

    end

  end

end
