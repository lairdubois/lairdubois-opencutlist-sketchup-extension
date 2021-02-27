module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Report

    include HashableHelper

    attr_reader :errors, :warnings, :tips

    def initialize(report_def)
      @_def = report_def

      @errors = []
      @warnings = []
      @tips = []

      @total_mass = report_def.total_mass
      @total_cost = report_def.total_cost

      @groups = []
      report_def.group_defs.each do |material_type, group_def|
        @groups.push(group_def.create_group)
      end
    end

    # ---

    # Errors

    def add_error(error)
      @errors.push(error)
    end

    # Warnings

    def add_warning(warning)
      @warnings.push(warning)
    end

    # Tips

    def add_tip(tip)
      @tips.push(tip)
    end

  end

end
