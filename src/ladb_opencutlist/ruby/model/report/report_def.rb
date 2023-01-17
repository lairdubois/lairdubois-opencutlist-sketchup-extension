module Ladb::OpenCutList

  require_relative 'report'
  require_relative 'report_group_def'

  class ReportDef

    attr_accessor :solid_wood_coefficient, :total_mass, :total_used_mass, :total_cost, :total_used_cost
    attr_reader :errors, :warnings, :tips, :group_defs

    def initialize

      @errors = []
      @warnings = []
      @tips = []

      @solid_wood_coefficient = 1.0

      @total_mass = 0
      @total_used_mass = 0

      @total_cost = 0
      @total_used_cost = 0

      @group_defs = {
          MaterialAttributes::TYPE_SOLID_WOOD => SolidWoodReportGroupDef.new,
          MaterialAttributes::TYPE_SHEET_GOOD => SheetGoodReportGroupDef.new,
          MaterialAttributes::TYPE_DIMENSIONAL => DimensionalReportGroupDef.new,
          MaterialAttributes::TYPE_EDGE => EdgeReportGroupDef.new,
          MaterialAttributes::TYPE_VENEER => VeneerReportGroupDef.new,
          MaterialAttributes::TYPE_HARDWARE => HardwareReportGroupDef.new,
      }

    end

    # ---

    def create_report
      Report.new(self)
    end

    # ---

    def total_unused_mass
      [@total_mass - @total_used_mass, 0].max
    end

    def total_unused_cost
      [@total_cost - @total_used_cost, 0].max
    end

  end

end
