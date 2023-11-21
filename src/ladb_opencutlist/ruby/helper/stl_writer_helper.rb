module Ladb::OpenCutList

  module StlWriterHelper

    # Unit

    def _stl_get_unit_transformation(unit)

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

    # Indent

    def _stl_indent(inc = 1)
      if @_stl_indent.nil?
        @_stl_indent = inc
      else
        @_stl_indent += inc
      end
    end

    def _stl_append_indent
      ''.ljust([ @_stl_indent.to_i, 0 ].max)
    end

    # -----

    def _stl_write_solid_start(file, name)
      file.puts("solid #{name}")
      _stl_indent
    end

    def _stl_write_solid_end(file, name)
      file.puts("endsolid #{name}")
      _stl_indent(-1)
    end


    def _stl_write_facet_start(file, nx, ny, nz)
      file.puts("#{_stl_append_indent}facet normal #{nx.to_f} #{ny.to_f} #{nz.to_f}")
      _stl_indent
    end

    def _stl_write_facet_end(file)
      file.puts("#{_stl_append_indent}endfacet")
      _stl_indent(-1)
    end


    def _stl_write_loop_start(file)
      file.puts("#{_stl_append_indent}outer loop")
      _stl_indent
    end

    def _stl_write_loop_end(file)
      file.puts("#{_stl_append_indent}endloop")
      _stl_indent(-1)
    end


    def _stl_write_vertex(file, x, y, z)
      file.puts("#{_stl_append_indent}vertex #{x.to_f} #{y.to_f} #{z.to_f}")
    end

  end

end