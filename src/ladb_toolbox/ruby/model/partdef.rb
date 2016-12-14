require 'securerandom'

class PartDef

  attr_accessor :name, :count, :raw_size, :size
  attr_reader :id, :definition_id, :component_ids

  def initialize(definition_id)
    @id = SecureRandom.uuid
    @definition_id = definition_id
    @name = ''
    @count = 0
    @raw_size = Size.new
    @size = Size.new
    @component_ids = []
  end

  def add_component_id(component_id)
    @component_ids.push(component_id)
  end

end