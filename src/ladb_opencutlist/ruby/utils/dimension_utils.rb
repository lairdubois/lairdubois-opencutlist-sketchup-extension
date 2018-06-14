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

  class DimensionUtils

    include Singleton

    # Marker
    MARKER = 'd:'.freeze

    # Separators
    LIST_SEPARATOR = ';'.freeze
    DXD_SEPARATOR = 'x'.freeze

    @separator
    @length_unit
    @length_format
    
    def initialize
      begin
        '1.0'.to_l
        @separator = '.'
      rescue
        @separator = ','
      end
      fetch_length_options
    end

    def fetch_length_options
      model = Sketchup.active_model
      @length_unit = model ? model.options['UnitsOptions']['LengthUnit'] : DECIMAL
      @length_format = model ? model.options['UnitsOptions']['LengthFormat'] : INCHES
    end

    # -----

    def from_fractional(i)
     input_split = (i.split('/').map( &:to_i ))
     Rational(*input_split)
    end

    def prefix_marker(i)
      MARKER + i
    end

    def strip_marker(i)
      i.sub(MARKER, '')
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

    # Take a fraction and try to simplify it by turning:
    # 1. x/0 into x
    # 2. 0/x into 0
    #
    def simplify(i)
      i = i.to_s
      if match = i.match(/^(\d*)\/(\d*)$/)
        num, den = match.captures
        if num == "0"
          return "0"
        elsif den == "1"
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
      return "0" + unit_sign if i.nil? || i.empty?
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
            nu.sub!(four, @separator)
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
        i = strip_marker(i)
        if match = i.match(/^(\d*(#{Regexp.escape(@separator)}\d*)?)?\s*(#{UNIT_SIGN_MILLIMETER}|#{UNIT_SIGN_CENTIMETER}|#{UNIT_SIGN_METER}|#{UNIT_SIGN_FEET}|#{UNIT_SIGN_INCHES})?$/)
          one, two, three = match.captures
          #puts "i = #{'%7s' % i} => decimal/integer number::  #{'%7s' % one}   #{'%7s' % three}"
          one = one.sub(/#{Regexp.escape(@separator)}/, '.')
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
        elsif match = i.match(/^(((\d*(#{Regexp.escape(@separator)}\d*)?)(\s*\')?)?\s+)?((\d*)\s+)?(\d*\/\d*)?(\s*\")?$/)
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
      sum = sum.to_s.sub(/\./, @separator)
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
    def dd_transform(i, f)
      return '' if i.nil?
      a = i.split(LIST_SEPARATOR)
      r = []
      a.each do |e|
        r << send(f, e)
      end
      r.join(LIST_SEPARATOR)
    end

    def dd_add_units(i)
      dd_transform(i, :str_add_units)
    end

    def dd_to_ifloats(i)
      dd_transform(i, :str_to_ifloat)
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
    def dxd_to_ifloats_str(i)
      dxd_transform(i, :str_to_ifloat)
    end
    
    # Normalize value for entry into the registry
    #
    def normalize(i)
      i = strip_marker(i)
      i = str_add_units(i)        # add units
      i = i.sub(/"/, '\"')        # escape double quote in string for registry
      i = prefix_marker(i)        # prefix marker
      i
    end

    # De-normalize value when reading from registry
    def denormalize(i)
      i = strip_marker(i)
      i = i.sub(/\\/, '"')        # unescape double quote feet single quote unit is not a problem   
      i
    end

  end
end