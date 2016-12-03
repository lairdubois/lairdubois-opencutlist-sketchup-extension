class Cutlist

  @filepath
  @length_unit
  @group_defs

  def initialize(filepath, length_unit)
    @filepath = filepath
    @length_unit = length_unit
    @group_defs = {}
  end

  def set_group_def(key, group_def)
    @group_defs[key] = group_def
  end

  def get_group_def(key)
    if @group_defs.has_key? key
      return @group_defs[key]
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
          :raw_area_m2 => 0,
          :raw_volume_m3 => 0,
          :pieces => []
      }
      output[:groups].push(group)

      # Sort and browse pieces
      code = 'A'
      group_def.piece_defs.sort_by { |k, v| [v.size.thickness, v.size.length, v.size.width] }.reverse.each { |key, piece_def|
        group[:raw_area_m2] += piece_def.raw_size.area_m2
        group[:raw_volume_m3] += piece_def.raw_size.volume_m3
        group[:pieces].push({
                                :name => piece_def.name,
                                :length => piece_def.size.length,
                                :width => piece_def.size.width,
                                :thickness => piece_def.size.thickness,
                                :count => piece_def.count,
                                :raw_length => piece_def.raw_size.length,
                                :raw_width => piece_def.raw_size.width,
                                :code => code,
                                :component_guids => piece_def.component_guids
                            }
        )
        code = code.succ
      }

    }

    JSON.generate(output)
  end

end