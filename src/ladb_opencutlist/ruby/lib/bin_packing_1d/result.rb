module Ladb::OpenCutList::BinPacking1D

  class Result
    def initialize(debug = false); end

    def prt_summary(packing, msg, with_id)
      if packing.bars.empty?
        print("NO bar available!\n")
        return
      end

      nb_bars = [0, 0, 0]
      lengths = [0, 0, 0, 0]

      print("\nRESULTS: #{msg}\n")
      print("-----------------------------------------------\n")
      print("Type       Bar L    Raw L /   Net L /   Waste\n")
      packing.bars.each do |bar|
        tmp = bar.result(with_id)
        lengths.each_with_index do |_e, i|
          lengths[i] += tmp[i]
        end
        nb_bars[bar.type] += 1
      end
      print("-----------------------------------------------\n")
      print("Total  [#{format('%<l>8s', l: lengths[0].to_l.to_s)} ")
      print("#{format('%<l1>8s', l1: lengths[1].to_l.to_s)} /")
      print("#{format('%<l2>8s', l2: lengths[2].to_l.to_s)} /")
      print("#{format('%<l3>8s', l3: lengths[3].to_l.to_s)}\n")
      print("-----------------------------------------------\n")
      eff = lengths[2].to_f / lengths[0] * 100
      print("Efficiency  #{format('%<l1>s', l1: lengths[2].to_l.to_s)}/")
      print("#{format('%<l2>s', l2: lengths[0].to_l.to_s)} = ")
      print("#{format('%<eff>.2f', eff: eff.to_f)} \%\n")
      print("Nb parts            : #{packing.nb_parts}\n")
      print("Placed parts        : #{packing.nb_parts - packing.unplaced_parts.length}\n")

      print("Unplaced parts      : #{packing.unplaced_parts.length}\n")
      print("Total unfit bars    : #{nb_bars[BAR_TYPE_UNFIT]}\n")
      print("Total leftover bars : #{nb_bars[BAR_TYPE_LO]}\n")
      vol = (nb_bars[BAR_TYPE_NEW] * packing.options.std_length * packing.options.bar_width * packing.options.bar_height)
      print("Total new bars      : #{nb_bars[BAR_TYPE_NEW]}\n")
      print('Volume              : ')
      print(" #{format('%<volume>.3f', volume: vol)} [in units]^3\n")
    end
  end
end
