class Cutlist

  STATUS_SUCCESS = 'success'

  @status
  @errors
  @warnings
  @filepath
  @length_unit
  @group_defs

  def initialize(status, filepath, length_unit)
    @status = status
    @errors = []
    @warnings = []
    @filepath = filepath
    @length_unit = length_unit
    @group_defs = {}
  end

  def add_error(error)
    @errors.push(error)
  end

  def add_warning(warning)
    @errors.push(warning)
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

  def to_json(code_sequence_by_group, piece_number_letter)

    puts piece_number_letter

    # Output JSON
    output = {
        :status => @status,
        :errors => @errors,
        :warnings => @warnings,
        :filepath => @filepath,
        :length_unit => @length_unit,
        :groups => []
    }

    # Sort and browse groups
    piece_number = piece_number_letter ? 'A' : '1'
    @group_defs.sort_by { |k, v| [v.raw_thickness] }.reverse.each { |key, group_def|

      if code_sequence_by_group
        piece_number = piece_number_letter ? 'A' : '1'    # Reset code increment on each group
      end

      group = {
          :id => group_def.id,
          :material_name => group_def.material_name,
          :piece_count => group_def.piece_count,
          :raw_thickness => group_def.raw_thickness,
          :raw_area_m2 => 0,
          :raw_volume_m3 => 0,
          :pieces => []
      }
      output[:groups].push(group)

      # Sort and browse pieces
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
                                :number => piece_number,
                                :component_guids => piece_def.component_guids
                            }
        )
        piece_number = piece_number.succ
      }

    }

    JSON.generate(output)
  end

end