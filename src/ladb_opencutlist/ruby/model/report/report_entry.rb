module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'

  class AbstractReportItem

    include HashableHelper

    attr_reader :total_mass, :total_cost

    def initialize(_def)
      @_def = _def

      @total_mass = _def.total_mass == 0 ? nil : MassUtils.instance.format_to_readable_mass(_def.total_mass)
      @total_cost = _def.total_cost == 0 ? nil : PriceUtils.instance.format_to_readable_price(_def.total_cost)

    end

  end

  class AbstractReportEntry < AbstractReportItem

    attr_reader :errors, :id, :material_id, :material_name, :material_display_name, :material_color, :material_type, :std_available, :std_dimension_stipped_name, :std_dimension, :std_thickness

    def initialize(_def)
      super(_def)

      @errors = _def.errors

      @id = _def.cutlist_group.id
      @material_id = _def.cutlist_group.material_id
      @material_name = _def.cutlist_group.material_name
      @material_display_name = _def.cutlist_group.material_display_name
      @material_color = _def.cutlist_group.material_color
      @material_type = _def.cutlist_group.material_type
      @std_available = _def.cutlist_group.std_available
      @std_dimension_stipped_name = _def.cutlist_group.std_dimension_stipped_name
      @std_dimension = _def.cutlist_group.std_dimension
      @std_thickness = _def.cutlist_group.std_thickness

    end

  end

  # -----

  class SolidWoodReportEntry < AbstractReportEntry

    attr_reader :total_volume

    def initialize(_def)
      super(_def)

      @volumic_mass = _def.volumic_mass.nil? || _def.volumic_mass[:val] == 0 ? nil : UnitUtils.format_readable(_def.volumic_mass[:val], _def.volumic_mass[:unit])
      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @total_volume = _def.total_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(_def.total_volume, @material_type)

    end

  end

  # -----

  class SheetGoodReportEntry < AbstractReportEntry

    attr_reader :volumic_mass,:std_price, :total_count, :total_area, :sheets

    def initialize(_def)
      super(_def)

      @volumic_mass = _def.volumic_mass.nil? || _def.volumic_mass[:val] == 0 ? nil : UnitUtils.format_readable(_def.volumic_mass[:val], _def.volumic_mass[:unit])

      @total_count = _def.total_count
      @total_area = _def.total_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(_def.total_area)

      @sheets = _def.sheet_defs.map { |sheet_def| sheet_def.create_sheet }

      @std_price = @sheets.map { |sheet| sheet.std_price }.select { |std_price| !std_price.nil? }.uniq.join(', ')

    end

  end

  class SheetGoodReportEntrySheet < AbstractReportItem

    attr_reader :std_price, :type, :length, :width, :count, :total_area

    def initialize(_def)
      super(_def)

      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @type = _def.cuttingdiagram2d_summary_sheet.type
      @length = _def.cuttingdiagram2d_summary_sheet.length
      @width = _def.cuttingdiagram2d_summary_sheet.width
      @count = _def.cuttingdiagram2d_summary_sheet.count
      @total_area = _def.cuttingdiagram2d_summary_sheet.total_area

    end

  end

  # -----

  class DimensionalReportEntry < AbstractReportEntry

    attr_reader :volumic_mass, :std_price, :total_count, :total_length, :bars

    def initialize(_def)
      super(_def)

      @volumic_mass = _def.volumic_mass.nil? || _def.volumic_mass[:val] == 0 ? nil : UnitUtils.format_readable(_def.volumic_mass[:val], _def.volumic_mass[:unit])

      @total_count = _def.total_count
      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

      @bars = _def.bar_defs.map { |bar_def| bar_def.create_bar }

      @std_price = @bars.map { |bar| bar.std_price }.select { |std_price| !std_price.nil? }.uniq.join(', ')

    end

  end

  class DimensionalReportEntryBar < AbstractReportItem

    attr_reader :std_price, :type, :length, :count, :total_length

    def initialize(_def)
      super(_def)

      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @type = _def.cuttingdiagram1d_summary_bar.type
      @length = _def.cuttingdiagram1d_summary_bar.length
      @count = _def.cuttingdiagram1d_summary_bar.count
      @total_length = _def.cuttingdiagram1d_summary_bar.total_length

    end

  end

  # -----

  class EdgeReportEntry < AbstractReportEntry

    attr_reader :volumic_mass, :std_price, :total_length

    def initialize(_def)
      super(_def)

      @volumic_mass = _def.volumic_mass.nil? || _def.volumic_mass[:val] == 0 ? nil : UnitUtils.format_readable(_def.volumic_mass[:val], _def.volumic_mass[:unit], 3)
      @std_price = _def.std_price.nil? || _def.std_price[:val] == 0 ? nil : UnitUtils.format_readable(_def.std_price[:val], _def.std_price[:unit], 2, 2)

      @total_length = _def.total_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(_def.total_length)

    end

  end

  # -----

  class HardwareReportEntry < AbstractReportEntry

    attr_reader :total_count

    def initialize(_def)
      super(_def)

      @total_count = _def.total_count

      @parts = _def.part_defs.map { |part_def| part_def.create_part }

    end

  end

  class HardwareReportEntryPart < AbstractReportItem

    attr_reader :id, :name, :flipped, :count, :mass, :price

    def initialize(_def)
      super(_def)

      @id = _def.cutlist_part.id
      @name = _def.cutlist_part.name
      @flipped = _def.cutlist_part.flipped
      @count = _def.cutlist_part.count

      @mass = _def.mass.nil? || _def.mass[:val] == 0 ? nil : UnitUtils.format_readable(_def.mass[:val], _def.mass[:unit], 3)
      @price = _def.price.nil? || _def.price[:val] == 0 ? nil : UnitUtils.format_readable(_def.price[:val], _def.price[:unit], 2, 2)

    end

  end

end
