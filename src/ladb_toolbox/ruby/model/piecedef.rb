class PieceDef

  attr_accessor :name, :count, :raw_size, :size
  attr_reader :component_guids

  def initialize
    @name = ''
    @count = 0
    @raw_size = Size.new
    @size = Size.new
    @component_guids = []
  end

  def add_component_guid(component_guid)
    @component_guids.push(component_guid)
  end

end