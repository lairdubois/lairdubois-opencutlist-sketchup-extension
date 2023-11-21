module Ladb::OpenCutList

  module ObjWriterHelper

    # Unit

    def _obj_get_unit_transformation(unit)

      require_relative '../utils/dimension_utils'

      case unit
      when DimensionUtils::INCHES
        unit_factor = 1.0
      when DimensionUtils::FEET
        unit_factor = 1.0.to_l.to_feet
      when DimensionUtils::YARD
        unit_factor = 1.0.to_l.to_yard
      when DimensionUtils::MILLIMETER
        unit_factor = 1.0.to_l.to_mm
      when DimensionUtils::CENTIMETER
        unit_factor = 1.0.to_l.to_cm
      when DimensionUtils::METER
        unit_factor = 1.0.to_l.to_m
      else
        unit_factor = DimensionUtils.instance.length_to_model_unit_float(1.0.to_l)
      end

      Geom::Transformation.scaling(ORIGIN, unit_factor, unit_factor, unit_factor)
    end

    # -----

    def _obj_write(file, key, value)
      file.puts("#{key} #{value}")
    end

    def _obj_write_group(file, name)
      _obj_write(file, 'g', name)
    end

    def _obj_write_normal(file, nx, ny, nz)
      _obj_write(file, 'vn', "#{nx.to_f} #{ny.to_f} #{nz.to_f}")
    end

    def _obj_write_vertex(file, x, y, z)
      _obj_write(file, 'v', "#{x.to_f} #{y.to_f} #{z.to_f}")
    end

  end

end