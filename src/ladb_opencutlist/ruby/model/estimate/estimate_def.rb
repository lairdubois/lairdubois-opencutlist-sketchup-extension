module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'estimate'
  require_relative 'estimate_group_def'

  class EstimateDef < DataContainer

    attr_accessor :total_mass, :total_used_mass, :total_cost, :total_used_cost
    attr_reader :errors, :warnings, :tips, :group_defs

    def initialize

      @errors = []
      @warnings = []
      @tips = []

      @total_mass = 0
      @total_used_mass = 0

      @total_cost = 0
      @total_used_cost = 0

      @group_defs = {
          MaterialAttributes::TYPE_SOLID_WOOD => SolidWoodEstimateGroupDef.new,
          MaterialAttributes::TYPE_SHEET_GOOD => SheetGoodEstimateGroupDef.new,
          MaterialAttributes::TYPE_DIMENSIONAL => DimensionalEstimateGroupDef.new,
          MaterialAttributes::TYPE_EDGE => EdgeEstimateGroupDef.new,
          MaterialAttributes::TYPE_VENEER => VeneerEstimateGroupDef.new,
          MaterialAttributes::TYPE_HARDWARE => HardwareEstimateGroupDef.new,
          -1 => CutEstimateGroupDef.new,
      }

    end

    # ---

    def create_estimate
      Estimate.new(self)
    end

    # ---

    def total_unused_mass
      [ @total_mass - @total_used_mass, 0 ].max
    end

    def total_unused_cost
      [ @total_cost - @total_used_cost, 0 ].max
    end

  end

end
