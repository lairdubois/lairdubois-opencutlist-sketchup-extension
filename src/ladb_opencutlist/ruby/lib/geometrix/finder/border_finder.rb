module Ladb::OpenCutList::Geometrix

  class BorderFinder

    def self.find_borders(outer_polygons, polygons)

      border_defs = []

      fn_point_on_border = lambda { |point, outer_polygon|
        !Geom::point_in_polygon_2D(point, outer_polygon, false)
      }

      fn_extract_border = lambda { |segment_defs|
        return [] if segment_defs.length < 3

        start_gate_index = segment_defs.index { |segment_def| segment_def.start_gate? }
        if start_gate_index.nil?

          border_def = BorderDef.new(segment_defs)
          border_defs << border_def if border_def.valid?

          return []
        else
          segment_defs.rotate!(start_gate_index)
          end_gate_index = segment_defs.index { |segment_def| segment_def.end_gate? }
          if end_gate_index.nil?
            return [] # Invalid border, no end gate
          else

            border_def = BorderDef.new(segment_defs[0..end_gate_index])
            border_defs << border_def if border_def.valid?

            return segment_defs[(end_gate_index + 1)..-1]
          end
        end

      }

      outer_polygons.each do |outer_polygon|
        polygons.each do |polygon|
          vertex_defs = polygon.map { |point| BorderVertexDef.new(point, fn_point_on_border.call(point, outer_polygon)) }
          segment_defs = (vertex_defs + [ vertex_defs.first ]).each_cons(2).map { |v1, v2|
            if (segment_def = BorderSegmentDef.new(v1, v2)).valid?
              if segment_def.border?
                mid_point = Geom.linear_combination(0.5, v1.position, 0.5, v2.position)
                if fn_point_on_border.call(mid_point, outer_polygon)
                  [ segment_def ]
                else
                  vm = BorderVertexDef.new(mid_point, false)
                  [
                    BorderSegmentDef.new(v1, vm),
                    BorderSegmentDef.new(vm, v2),
                  ]
                end
              else
                [ segment_def ]
              end
            end
          }.compact.flatten(1)

          until segment_defs.empty?
            segment_defs = fn_extract_border.call(segment_defs)
          end

        end
      end

      border_defs
    end

  end

  # -----

  class BorderDef

    attr_reader :segment_defs

    def initialize(segment_defs)
      @segment_defs = segment_defs
    end

    def valid?
      @segment_defs.any?
    end

    def closed?
      @segment_defs.index { |segment_def| segment_def.start_gate? }.nil?
    end

    def points
      points = []
      @segment_defs.each do |segment_def|
        next unless segment_def.border? || segment_def.end_gate?
        points << segment_def.start_vertex_def.position
      end
      points << points.first if closed?
      points
    end

  end

  class BorderSegmentDef

    attr_reader :start_vertex_def, :end_vertex_def

    def initialize(start_vertex_def, end_vertex_def)
      @start_vertex_def = start_vertex_def
      @end_vertex_def = end_vertex_def
    end

    def border?
      @start_vertex_def.on_border && @end_vertex_def.on_border
    end

    def start_gate?
      !@start_vertex_def.on_border && @end_vertex_def.on_border
    end

    def end_gate?
      @start_vertex_def.on_border && !@end_vertex_def.on_border
    end

    def valid?
      @start_vertex_def.on_border || @end_vertex_def.on_border
    end

  end

  class BorderVertexDef

    attr_accessor :position, :on_border

    def initialize(position, on_border)
      @position = position
      @on_border = on_border
    end

  end

end