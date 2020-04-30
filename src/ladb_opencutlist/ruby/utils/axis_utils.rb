module Ladb::OpenCutList

  class AxisUtils

    def self.flipped?(xaxis, yaxis, zaxis)
      xaxis.cross(yaxis) != zaxis
    end

  end

end

