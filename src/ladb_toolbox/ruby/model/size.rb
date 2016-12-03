class Size

  attr_accessor :length
  attr_accessor :width
  attr_accessor :thickness

  def initialize(length = 0, width = 0, thickness = 0)
    @length = length
    @width = width
    @thickness = thickness
  end

  def area_m2
    @length.to_m * @width.to_m
  end

  def volume_m3
    area_m2 * @thickness.to_m
  end

end
