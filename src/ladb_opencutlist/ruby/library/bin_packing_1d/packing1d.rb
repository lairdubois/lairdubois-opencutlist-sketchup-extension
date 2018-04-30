module BinPacking1D
  class Packing1D

    @@debugging = true
    
    def db(str)
      if @@debugging then
        puts " " + str
      end
    end
    
    def pstr(str)
      puts " " + str
    end
    
    # convert to model units
    def cu(l)
      return "#{l}\"".to_l.to_s
    end
  end
end