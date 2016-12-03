class Size

  attr_accessor :length
  attr_accessor :width
  attr_accessor :thickness

  def initialize(length = 0, width = 0, thickness = 0)
    @length = length
    @width = width
    @thickness = thickness
  end

  def area
    @length * @width
  end

  def volume
    area * @thickness
  end

end
