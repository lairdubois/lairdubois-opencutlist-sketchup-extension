module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Report

    include HashableHelper

    attr_reader :errors, :warnings, :tips, :total_mass, :total_cost, :groups

    def initialize(report_def)
      @_def = report_def

      @errors = report_def.errors
      @warnings = report_def.warnings
      @tips = report_def.tips

      @total_mass = report_def.total_mass
      @total_cost = report_def.total_cost

      @groups = []
      report_def.group_defs.each do |material_type, group_def|
        @groups.push(group_def.create_group)
      end
    end

  end

end
