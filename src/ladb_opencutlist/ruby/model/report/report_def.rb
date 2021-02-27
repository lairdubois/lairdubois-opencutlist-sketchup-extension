module Ladb::OpenCutList

  require_relative 'report'
  require_relative 'report_groupdef'

  class ReportDef

    attr_accessor :total_mass, :total_cost
    attr_reader :group_defs

    def initialize

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

    # Groups

    def get_group_def(material_type)
      @group_defs[material_type]
    end

  end

end
