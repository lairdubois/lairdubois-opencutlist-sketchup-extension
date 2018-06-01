module Ladb::OpenCutList

  class StringUtils

    # -- Dimensions --

    def self.split_dxd(str)
      value1 = '0'
      value2 = '0'
      if str.is_a? String
        a = str.split('x')
        if a.length == 2
          value1 = a[0].strip
          value2 = a[1].strip
        end
      end
      return value1, value2
    end

    def self.split_dxdxd(str)
      value1 = '0'
      value2 = '0'
      value3 = '0'
      if str.is_a? String
        a = str.split('x')
        if a.length == 3
          value1 = a[0].strip
          value2 = a[1].strip
          value3 = a[2].strip
        end
      end
      return value1, value2, value3
    end

  end

end

