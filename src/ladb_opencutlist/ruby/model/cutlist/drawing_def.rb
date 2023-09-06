module Ladb::OpenCutList

  class DrawingDef

    attr_reader :bounds, :face_infos, :edge_infos
    attr_accessor :transformation, :x_axis, :y_axis, :z_axis, :active_face_info, :active_edge_info

    def initialize

      @bounds = Geom::BoundingBox.new
      @face_infos = []
      @edge_infos = []

      @transformation = Geom::Transformation.new

      @x_axis = nil
      @y_axis = nil
      @z_axis = nil

      @active_face_info = nil
      @active_edge_info = nil

    end

    def view
      unless @z_axis.nil?
        if @z_axis.parallel?(Z_AXIS)
          return 'TOP' if @z_axis.samedirection?(Z_AXIS)
          return 'BOTTOM'
        elsif @z_axis.parallel?(X_AXIS)
          return 'RIGHT' if @z_axis.samedirection?(X_AXIS)
          return 'LEFT'
        elsif @z_axis.parallel?(Y_AXIS)
          return 'BACK' if @z_axis.samedirection?(Y_AXIS)
          return 'FRONT'
        end
      end
      nil
    end

  end

end