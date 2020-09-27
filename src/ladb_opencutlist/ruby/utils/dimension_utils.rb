module Ladb::OpenCutList

  require 'singleton'

  # Format - just here for convenience
  DECIMAL       = Length::Decimal
  ARCHITECTURAL = Length::Architectural
  ENGINEERING   = Length::Engineering
  FRACTIONAL    = Length::Fractional

  # Unit - just here for convenience
  INCHES        = Length::Inches
  FEET          = Length::Feet
  MILLIMETER    = Length::Millimeter
  CENTIMETER    = Length::Centimeter
  METER         = Length::Meter

  # Unit signs
  UNIT_SIGN_INCHES = '"'
  UNIT_SIGN_FEET = "'"
  UNIT_SIGN_METER = 'm'
  UNIT_SIGN_CENTIMETER = 'cm'
  UNIT_SIGN_MILLIMETER = 'mm'

  UNIT_SIGN_METER_2 = 'm²'
  UNIT_SIGN_FEET_2 = 'ft²'

  UNIT_SIGN_METER_3 = 'm³'
  UNIT_SIGN_FEET_3 = 'ft³'

  class DimensionUtils

    include Singleton

    attr_accessor :decimal_separator, :length_unit

    # Separators
    LIST_SEPARATOR = ';'.freeze
    DXD_SEPARATOR = 'x'.freeze

    @separator
    @length_unit
    @length_format
    @length_precision

    def initialize
      begin
        '1.0'.to_l
        @decimal_separator = '.'
      rescue
        @decimal_separator = ','
      end
      fetch_length_options
    end

    def fetch_length_options
      model = Sketchup.active_model
      @length_unit = model ? model.options['UnitsOptions']['LengthUnit'] : MILLIMETER
      @length_format = model ? model.options['UnitsOptions']['LengthFormat'] : DECIMAL
      @length_precision = model ? model.options['UnitsOptions']['LengthPrecision'] : 0
    end

    # -----

    def from_fractional(i)
     input_split = (i.split('/').map( &:to_i ))
     Rational(*input_split)
    end

    def model_units_to_inches(i)
      case @length_unit
      when MILLIMETER
        return i / 25.4
      when CENTIMETER
        return i / 2.54
      when METER
        return i / 0.0254
      when FEET
        return i * 12
      else
        return i
      end
    end

    def unit_sign
      case @length_unit
        when MILLIMETER
          return UNIT_SIGN_MILLIMETER
        when CENTIMETER
          return UNIT_SIGN_CENTIMETER
        when METER
          return UNIT_SIGN_METER
        when FEET
          return UNIT_SIGN_FEET
        else
          return UNIT_SIGN_INCHES
      end
    end

    def model_unit_is_metric
      case @length_unit
        when MILLIMETER, CENTIMETER, METER
          return true
        else
          return false
      end
    end

    # Take a fraction and try to simplify it by turning:
    # 1. x/0 into x
    # 2. 0/x into 0
    #
    def simplify(i)
      i = i.to_s
      match = i.match(/^(\d*)\/(\d*)$/)
      if match
        num, den = match.captures
        if num == '0'
          return '0'
        elsif den == '1'
          return num
        else
          return i
        end
      else
        i
      end
    end
    
    # Take a single dimension as a string and
    # 1. add units if none are present, assuming that no units means model units
    # 2. prepend zero if just unit given (may happen!)
    # 3. add units if none
    # 4. convert garbage into 0
    #
    def str_add_units(i)
      return '0' + unit_sign if i.nil? || i.empty?
      i = i.strip
      nu = ""
      sum = 0
      if i.is_a?(String) 
        if match = i.match(/^(~?\s*)(\d*(([.,])\d*)?)?\s*(#{UNIT_SIGN_MILLIMETER}|#{UNIT_SIGN_CENTIMETER}|#{UNIT_SIGN_METER}|#{UNIT_SIGN_FEET}|#{UNIT_SIGN_INCHES})?$/)
          one, two, three, four, five = match.captures
          if five.nil?
            nu = one + two + unit_sign
          elsif two.empty? and three.nil?  # two could not be nil
            nu = one + "0" + five
          else
            nu = one + two + five
            #nu = nu.sub(/"/, '\"') # four will not be escaped in this case
          end
          if !four.nil?
            nu.sub!(four, @decimal_separator)
          end
        elsif match = i.match(/^~?\s*(((\d*([.,]\d*)?)(\s*\')?)?\s+)?((\d*)\s+)?(\d*\/\d*)?(\s*\")?$/)
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
          nu = '0' + unit_sign # garbage becomes 0
        end
      end
      nu
    end

    # Takes a single dimension as a string and converts it into a decimal inch
    # returns the float as a string
    def str_to_ifloat(i)
     i = i.sub(/~/, '') # strip approximate sign away
     i = i.strip
     sum = 0
      # make sure the entry is a string and starts with the proper magic
      if i.is_a?(String) 
        if match = i.match(/^(\d*([.,]\d*)?)?\s*(#{UNIT_SIGN_MILLIMETER}|#{UNIT_SIGN_CENTIMETER}|#{UNIT_SIGN_METER}|#{UNIT_SIGN_FEET}|#{UNIT_SIGN_INCHES})?$/)
          one, two, three = match.captures
          #puts "i = #{'%7s' % i} => decimal/integer number::  #{'%7s' % one}   #{'%7s' % three}"
          one = one.sub(/,/, '.')
          one = one.to_f
          if three.nil?
            sum = model_units_to_inches(one)
          elsif three == UNIT_SIGN_MILLIMETER
            sum = one / 25.4
          elsif three == UNIT_SIGN_CENTIMETER
            sum = one / 2.54
          elsif three == UNIT_SIGN_METER
            sum = one / 0.0254
          elsif three == UNIT_SIGN_FEET
            sum = 12 * one
          elsif three == UNIT_SIGN_INCHES
            sum = one
          end
        elsif match = i.match(/^(((\d*([.,]\d*)?)(\s*\')?)?\s+)?((\d*)\s+)?(\d*\/\d*)?(\s*\")?$/)
          one, two, three, four, five, six, seven, eight, nine = match.captures
          if three.nil? && six.nil?
            #puts "i = #{'%15s' % i} => fractional+unit:: #{'%7s' % eight}  #{nine}"
            sum = from_fractional(eight).to_f
          elsif seven.nil? && five.nil?
            #puts "i = #{'%15s' % i} => inch+fractional+unit #{'%7s' % three} #{'%7s' % eight} #{nine}"
            sum = three.to_f + from_fractional(eight).to_f
          elsif seven.nil? && five == "'"
            #puts "i = #{'%15s' % i} => feet+fractional+unit:: #{'%7s' % three} #{four} #{'%7s' % seven} #{eight} #{nine}"
            sum = 12 * three.to_f + from_fractional(eight).to_f
          else
            #puts "i = #{'%15s' % i} => feet+inch+fractional+unit:: #{'%7s' % three} #{five} #{'%7s' % seven}#{'%7s' % eight} #{nine}"
            sum = 12 * three.to_f + six.to_f + from_fractional(eight).to_f
            sum = sum.to_f # force number to be a float, may not be necessary!
          end
        else
          sum = 0 # garbage always becomes 0
        end
      end
      sum = sum.to_s.sub(/\./, @decimal_separator)
      sum + UNIT_SIGN_INCHES
    end

    # Takes a single number in a string and converts it to a string
    # in Sketchup internal format (inches, decimal) with unit sign
    #
    def str_to_istr(i)
      str_to_ifloat(i)
    end

    # Splits a string in the form d;d;...
    # into single d's and applies the function f to each element
    # returns the concatenated string in the same format
    #
    def d_transform(i, f)
      return '' if i.nil?
      a = i.split(LIST_SEPARATOR)
      r = []
      a.each do |e|
        r << send(f, e)
      end
      r.join(LIST_SEPARATOR)
    end

    def d_add_units(i)
      d_transform(i, :str_add_units)
    end

    def d_to_ifloats(i)
      d_transform(i, :str_to_ifloat)
    end

    # Splits a string in the form dxd;dxd;...
    # into single d's and applies the function f to each element
    # returns the concatenated string in the same format
    #
    def dxd_transform(i, f)
      return '' if i.nil?
      a = i.split(LIST_SEPARATOR)
      r = []
      a.each do |e|
        ed = e.split(DXD_SEPARATOR)
        ed[0] = '0' if ed[0].nil? || ed[0].empty?
        ed[1] = '0' if ed[1].nil? || ed[1].empty?
        r << (send(f, ed[0]) + ' ' + DXD_SEPARATOR + ' ' + send(f, ed[1]))
      end
      r.join(LIST_SEPARATOR)
    end

    # Take a string containing dimensions in the form dxd;dxd;dxd;...
    # and make sure they all have units and are not empty
    # without units, model units are assumed and added
    #
    def dxd_add_units(i)
      dxd_transform(i, :str_add_units)
    end

    # Take a string containing dimensions in the form dxd;dxd;dxd;...
    # and convert them into a decimal inch number (Sketchup internal
    # format)
    # the number is returned as a string NOT a length or float
    #
    def dxd_to_ifloats(i)
      dxd_transform(i, :str_to_ifloat)
    end

    # Splits a string in the form dxq;dxq;...
    # into single d's and applies the function f to each element. q stay unchanged.
    # returns the concatenated string in the same format
    #
    def dxq_transform(i, f)
      return '' if i.nil?
      a = i.split(LIST_SEPARATOR)
      r = []
      a.each do |e|
        ed = e.split(DXD_SEPARATOR)
        ed[0] = '0' if ed[0].nil? || ed[0].empty?
        ed[1] = '0' if ed[1].nil? || ed[1].empty?
        r << (send(f, ed[0]) + (ed[1] == '0' ? '' : ' ' + DXD_SEPARATOR + ed[1].strip))
      end
      r.join(LIST_SEPARATOR)
    end

    # Take a string containing dimensions in the form dxq;dxq;dxq;...
    # and make sure they all have units and are not empty
    # without units, model units are assumed and added
    #
    def dxq_add_units(i)
      dxq_transform(i, :str_add_units)
    end

    # Take a string containing dimensions in the form dxq;dxq;dxq;...
    # and convert them into a decimal inch number (Sketchup internal
    # format)
    # the number is returned as a string NOT a length or float
    #
    def dxq_to_ifloats(i)
      dxq_transform(i, :str_to_ifloat)
    end

    # Splits a string in the form dxdxq;dxdxq;...
    # into single d's and applies the function f to each element. q stay unchanged.
    # returns the concatenated string in the same format
    #
    def dxdxq_transform(i, f)
      return '' if i.nil?
      a = i.split(LIST_SEPARATOR)
      r = []
      a.each do |e|
        ed = e.split(DXD_SEPARATOR)
        ed[0] = '0' if ed[0].nil? || ed[0].empty?
        ed[1] = '0' if ed[1].nil? || ed[1].empty?
        ed[2] = '0' if ed[2].nil? || ed[2].empty?
        r << (send(f, ed[0]) + ' ' + DXD_SEPARATOR + ' ' + send(f, ed[1]) + (ed[2] == '0' ? '' :  ' ' + DXD_SEPARATOR + ed[2].strip))
      end
      r.join(LIST_SEPARATOR)
    end

    # Take a string containing dimensions in the form dxdxq;dxdxq;dxdxq;...
    # and make sure they all have units and are not empty
    # without units, model units are assumed and added
    #
    def dxdxq_add_units(i)
      dxdxq_transform(i, :str_add_units)
    end

    # Take a string containing dimensions in the form dxdxq;dxdxq;dxdxq;...
    # and convert them into a decimal inch number (Sketchup internal
    # format)
    # the number is returned as a string NOT a length or float
    #
    def dxdxq_to_ifloats(i)
      dxdxq_transform(i, :str_to_ifloat)
    end

    # -----

    # Take a float containing a length in inch
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def format_to_readable_length(f)
      if f.nil?
        return nil
      end
      if model_unit_is_metric
        multiplier = 0.0254
        precision = 3
        unit_sign = UNIT_SIGN_METER
      else
        multiplier = 1 / 12.0
        precision = 2
        unit_sign = UNIT_SIGN_FEET
      end
      format_value(f, multiplier, precision, unit_sign)
    end

    # Take a float containing an area in inch²
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def format_to_readable_area(f2)
      if f2.nil?
        return nil
      end
      if model_unit_is_metric
        multiplier = 0.0254**2
        precision = [3, @length_precision].max
        unit_sign = UNIT_SIGN_METER_2
      else
        multiplier = 1 / 144.0
        precision = [2, @length_precision].max
        unit_sign = UNIT_SIGN_FEET_2
      end
      format_value(f2, multiplier, precision, unit_sign)
    end

    # Take a float containing a volume in inch³
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def format_to_readable_volume(f3)
      if f3.nil?
        return nil
      end
      if model_unit_is_metric
        multiplier = 0.0254**3
        precision = [3, @length_precision].max
        unit_sign = UNIT_SIGN_METER_3
      else
        multiplier = 1 / 1728.0
        precision = [2, @length_precision].max
        unit_sign = UNIT_SIGN_FEET_3
      end
      format_value(f3, multiplier, precision, unit_sign)
    end

    def format_value(f, multiplier, precision, unit_sign)
      value = f * multiplier
      rounded_value = value.round(precision)
      ((value - rounded_value).abs > 0.0001 ? '~ ' : '') + ("%.#{precision}f" % rounded_value).tr('.', @decimal_separator) + unit_sign
    end

    # -----

    # Take a float containing a length in inch
    # and truncate it to "Sketchup" precision
    def truncate_length_value(f)
      return f if f == 0
      factor = 10**4 # 4 = 0.0000 arbitrary length precision
      (f * factor).floor / (factor * 1.0)
    end

  end
end