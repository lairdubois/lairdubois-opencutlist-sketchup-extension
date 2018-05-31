module Ladb::OpenCutList

  # Format - will go away after testing
  DECIMAL       = Length::Decimal
  ARCHITECTURAL = Length::Architectural
  ENGINEERING   = Length::Engineering
  FRACTIONAL    = Length::Fractional

  # Unit - will go away after testing
  INCHES        = Length::Inches
  FEET          = Length::Feet
  MILLIMETER    = Length::Millimeter
  CENTIMETER    = Length::Centimeter
  METER         = Length::Meter

  class DimensionUtils

    def initialize ()
      @separator = Sketchup::RegionalSettings.decimal_separator
      @length_unit = Sketchup.active_model.options['UnitsOptions']['LengthUnit']
      @length_format = Sketchup.active_model.options['UnitsOptions']['LengthFormat']
      #@separator = '.'
      #@length_unit = length_unit
      #@length_format = length_format
    end

    def from_fractional(i)
     input_split = (i.split('/').map( &:to_i ))
     return Rational(*input_split)
    end

    def strip_marker(i)
      return i.sub('d:', '')
    end

    def model_units_to_inches(i)
      case @length_unit
      when MILLIMETER
        return i/25.4
      when CENTIMETER
        return i/2.54
      when METER
        return i/0.0254
      when FEET
        return i*12
      else
        return i
      end
    end

    def unit_sign
      case @length_unit
      when MILLIMETER
        return "mm"
      when CENTIMETER
        return "cm"
      when METER
        return "m"
      when FEET
        return "'"
      else
        return '"'
      end
    end

    def inches_to_model_units(i)
=begin
i = i.to_f
      case @length_unit
      when MILLIMETER
        i = i*25.4
      when CENTIMETER
        i = i*2.54
      when METER
        i = i*0.0254
      when FEET
        i =  i/12.0
      end
      return i.to_s
=end
      # in Sketchup the whole function is just:
      i = i.to_s + '"'
      return i.to_l     
    end

    def simplify(i)
      i = i.to_s
      if match = i.match(/^(\d*)\/(\d*)$/)
        num,den = match.captures
        if num == "0"
          return "0"
        elsif den == "1"
          return num
        else
          return i
        end
      else
        return i
      end
    end

    def is_fractional(i)
    
    end
    
    # Take a single dimension as a string and
    # 1. add units if none are present, assuming that no units means model units
    # 2. convert fractional inches into decimal inches and add units if none
    #
    def str_add_units(i)
      return '' if i.nil?
      i = i.strip
      nu = ""
      sum = 0
      if i.class == String 
        if match = i.match(/^(~?\s*)(\d*(#{Regexp.escape(@separator)}\d*)?)?\s*(mm|cm|m|'|")?$/)
          one, two, three, four = match.captures
          if four.nil?
            nu = one + two + unit_sign
          else
            nu = one + two + four
            #nu = nu.sub(/"/, '\"') # four will not be escaped in this case
         end
        elsif match = i.match(/^~?\s*(((\d*(#{Regexp.escape(@separator)}\d*)?)(\s*\')?)?\s+)?((\d*)\s+)?(\d*\/\d*)?(\s*\")?$/)
          one, two, three, four, five, six, seven, eight, nine = match.captures
          if three.nil? && six.nil?
            nu = simplify(from_fractional(eight)).to_s + '"'
            #sum = from_fractional(eight).to_f
          elsif seven.nil? && five.nil?
            nu = three + " " + eight + '"'
            #sum = three.to_f + from_fractional(eight).to_f
          elsif seven.nil? && five == "'"
            nu = three + "' " + eight + '"'
            #sum = 12*three.to_f + from_fractional(eight).to_f
          else
            nu = three + "' " + seven + " " + eight + '"'
            #sum = 12*three.to_f + six.to_f + from_fractional(eight).to_f
          end
        else
          nu = "0" + unit_sign # garbage becomes 0
        end
      end
      return nu
    end

    # Takes a single dimension as a string and converts it into a decimal inch
    # returns the float as a string
    def str_to_ifloat(i)
     i = i.sub(/~/, '') # strip approximate sign away
     i = i.strip
     sum = 0
      # make sure the entry is a string and starts with the proper magic
      if i.class == String #&& i.start_with?('d:')
        i = strip_marker(i)
        if match = i.match(/^(\d*(#{Regexp.escape(@separator)}\d*)?)?\s*(mm|cm|m|'|")?$/)
          one, two, three = match.captures
          #puts "i = #{'%7s' % i} => decimal/integer number::  #{'%7s' % one}   #{'%7s' % three}"
          one = one.to_f
          if three.nil?
            sum = model_units_to_inches(one) 
          elsif three == "mm"
            sum = one/25.4
          elsif three == "cm"
            sum = one/2.54
          elsif three == "m"
            sum = one/0.0254
          elsif three == '"'
            sum = one
          elsif three == "'"
            sum = 12*one
          end
        elsif match = i.match(/^(((\d*(#{Regexp.escape(@separator)}\d*)?)(\s*\')?)?\s+)?((\d*)\s+)?(\d*\/\d*)?(\s*\")?$/)
          one, two, three, four, five, six, seven, eight, nine = match.captures
          if three.nil? && six.nil?
            #puts "i = #{'%15s' % i} => fractional+unit:: #{'%7s' % eight}  #{nine}"
            sum = from_fractional(eight)
          elsif seven.nil? && five.nil?
            #puts "i = #{'%15s' % i} => inch+fractional+unit #{'%7s' % three} #{'%7s' % eight} #{nine}"
            sum = three.to_f + from_fractional(eight)
          elsif seven.nil? && five == "'"
            #puts "i = #{'%15s' % i} => feet+fractional+unit:: #{'%7s' % three} #{four} #{'%7s' % seven} #{eight} #{nine}"
            sum = 12*three.to_f + from_fractional(eight)
          else
            #puts "i = #{'%15s' % i} => feet+inch+fractional+unit:: #{'%7s' % three} #{five} #{'%7s' % seven}#{'%7s' % eight} #{nine}"
            sum = 12*three.to_f + six.to_f + from_fractional(eight)
          end
        else
          sum = 0 # garbage always becomes 0
        end
      end
      sum = sum.to_s.sub(/\./, @separator)
      return sum + '"'
    end

    # Takes a single number in a string and converts it to a string
    # in Sketchup internal format (inches, decimal) with unit sign
    #
    def str_to_istr(i)
      return str_to_ifloat(i)
    end

    def dd_transform(i, f)
      return '' if i.nil?
      a = i.split(';')
      r = []
      a.each do |e|
        r << send(f, e)
      end
      return r.join(';')
    end

    def dd_add_units(i)
      return dd_transform(i, :str_add_units)
    end

    def dd_to_ifloats(i)
      return dd_transform(i, :str_to_ifloat)
    end

    def dxd_transform(i, f)
      return '' if i.nil?
      a = i.split(';')
      r = []
      a.each do |e|
        ed = e.split('x')
        ed[0] = '0' if ed[0] == '' || ed[0].nil?
        ed[1] = '0' if ed[1] == '' || ed[1].nil?
        r << (send(f, ed[0]) + ' x ' + send(f, ed[1]))
      end
      return r.join(';')  
    end

    def dxd_add_units(i)
      return dxd_transform(i, :str_add_units)
    end

    def dxd_to_ifloats(i)
      return dxd_transform(i, :str_to_ifloat)
    end

  end
end