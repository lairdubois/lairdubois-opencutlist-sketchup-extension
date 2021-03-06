module Ladb::OpenCutList

  module UnitHelper

    def _split_unit_and_value(str)
      return nil, 0.0 unless str.is_a?(String)
      unit = nil
      val = str
      unless str.nil?
        a = str.split(' ')
        if a.length > 1
          unit = a.last
          val = a.slice(0, a.length - 1).join(' ')
        end
      end
      val = val.tr(',', '.').to_f
      return unit, val
    end

  end

end