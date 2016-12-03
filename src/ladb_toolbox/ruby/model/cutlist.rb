Group = Struct.new(:name, :raw_thickness, :piece_defs )
Piece = Struct.new(:name, :count, :raw_dim, :dim, :component_guids )

class Cutlist

  @filepath
  @length_unit
  @group_defs

  def initialize(filepath, length_unit)
    @filepath = filepath
    @length_unit = length_unit
    @group_defs = []
  end

  def set_group_def(key, group_def)
    @group[key] = group_def
  end

  def get_group_def(key)
    if @group_defs.has_key? key
      @group[key]
    end
    nil
  end

  def to_json

    # Output JSON
    output = {
        :filepath => @filepath,
        :length_unit => @length_unit,
        :groups => []
    }

    # Sort and browse groups
    @group_defs.sort_by { |k, v| [v.raw_thickness] }.reverse.each { |key, group_def|

      group = {
          :name => group_def.name,
          :raw_thickness => group_def.raw_thickness,
          :raw_area => 0,
          :raw_volume => 0,
          :pieces => []
      }
      output[:groups].push(group)

      # Sort and browse pieces
      code = 0
      group_def.piece_defs.sort_by { |k, v| [v.dim.thickness, v.dim.length, v.dim.width] }.reverse.each { |key, piece_def|
        group[:raw_area] += piece_def.raw_dim.area
        group[:raw_volume] += piece_def.raw_dim.volume
        group[:pieces].push({
                                :name => piece_def.name,
                                :length => piece_def.dim.length,
                                :width => piece_def.dim.width,
                                :thickness => piece_def.dim.thickness,
                                :count => piece_def.count,
                                :raw_length => piece_def.raw_dim.length,
                                :raw_width => piece_def.raw_dim.width,
                                :code => code.to_s,
                                :component_guids => piece_def.component_guids
                            }
        )
        code += 1
      }
    }

    JSON.generate(output)
  end

end