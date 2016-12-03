class GroupDef

  attr_accessor :name, :raw_thickness
  attr_reader :piece_defs

  def initialize
    @name = ''
    @raw_thickness = 0
    @piece_defs = {}
  end

  def set_piece(key, piece)
    @piece_defs[key] = piece
  end

  def get_piece(key)
    if @piece_defs.has_key? key
      @piece_defs[key]
    end
    nil
  end

end