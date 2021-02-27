module Ladb::OpenCutList

  require_relative 'report'
  require_relative 'report_group_def'

  class ReportDef

    attr_accessor :total_mass, :total_cost
    attr_reader :errors, :warnings, :tips, :group_defs

    def initialize

      @errors = []
      @warnings = []
      @tips = []

      @total_mass = 0
      @total_cost = 0

      @group_defs = {
          MaterialAttributes::TYPE_SOLID_WOOD => SolidWoodReportGroupDef.new,
          MaterialAttributes::TYPE_SHEET_GOOD => SheetGoodReportGroupDef.new,
          MaterialAttributes::TYPE_DIMENSIONAL => DimensionalReportGroupDef.new,
          MaterialAttributes::TYPE_EDGE => EdgeReportGroupDef.new,
          MaterialAttributes::TYPE_ACCESSORY => AccessoryReportGroupDef.new,
      }
    end

    # ---

    def create_report
      Report.new(self)
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

    # Groups

    def get_group_def(material_type)
      @group_defs[material_type]
    end

  end

end
