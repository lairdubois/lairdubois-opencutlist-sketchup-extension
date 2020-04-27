module Ladb::OpenCutList::BinPacking1D
  
  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX_INT = 2**(N_BITS - 2) - 1

  # Used by Timer for execution of algorithm
  class TimeoutError < StandardError
  end

  class Packer < Packing1D
    attr_accessor :options, :parts, :leftovers, :bars,
                  :unplaced_parts, :total_nb_parts, :efficiency

    def initialize(options)
      @options = options

      @parts = {}
      @leftovers = []

      @smallest = 0
      @total_nb_parts = 0
      @count = 0
      @nb_over_fiftypercent = 0
      @opt_nb_bars = MAX_PARTS

      @bars = []
      @unplaced_parts = []

      @efficiency = 0
    end

    def run
      err = ERROR_NONE

      start_time = Time.now if @options.max_time

      remove_unfit
      # compute basic statistics to estimate the number of bars needed
      estimate_optimal
      
      # split into chunks never larger than MAX_PARTS
      # otherwise computation may take forever or be interrupted by timer
      q = @parts.each_slice(MAX_PARTS)

      best_bars = []
      best_bars_length = MAX_INT
      leftover_bars_length = 0
      opt_found = false
      #
      # compute this t times with different epsilon's, keep the best
      #
      begin
        print("-> pack start\n") if @options.debug
        count = 1
        tuning = get_tuning(@options.tuning_level)
        puts(tuning.to_s)
        tuning.each do |factor|
          next if @smallest*factor > @options.std_length
          puts("   pass #{count} factor #{factor}") if @options.debug
          if @options.max_time && (Time.now - start_time > @options.max_time)
            puts('timeout... why?')
            raise(TimeoutError, 'timeout expired')
          end

          lo = @leftovers.clone
          if @options.std_length < EPS
            bars, err = pack_single(q, lo, factor)
          else
            bars, err = pack_single(q, [], factor)
          end
          if err == ERROR_NONE
            if bars.length <= @opt_nb_bars
              if @options.debug
                print("     [#{count}]: optimal solution, bars = #{bars.length}\n")
              end
              opt_found = true
            else
              if @options.debug
                print("     [#{count}]: suboptimal solution, bars = #{bars.length}\n")
              end
            end
            lo_bars = get_largest_leftover(bars)
            if bars.length < best_bars_length
              best_bars = bars
              best_bars_length = bars.length
              leftover_bars_length = lo_bars
              if @options.debug
                print("     [#{count}]: best bars #{bars.length}, leftover #{to_ls(leftover_bars_length)}\n")
              end
            elsif (bars.length == best_bars_length) && (lo_bars > leftover_bars_length)
              best_bars = bars
              best_bars_length = bars.length
              leftover_bars_length = lo_bars
              if @options.debug
                print("     [#{count}]: equal best bars #{bars.length}, larger leftover #{lo_bars}\n")
              end
            else
              print("     [#{count}]: not getting better\n") if @options.debug
            end
            count += 1
          else
            puts('BIG PROBLEM ', err)
          end
        end
      rescue StandardError
        err = ERROR_TIME_EXCEEDED if best_bars.empty?
      end
      @bars = best_bars
      print("-> total time = #{Time.now - start_time}\n") if @options.debug
      # check_optimality
      # check_leftover

      err = ERROR_SUBOPT if !opt_found && (err != ERROR_TIME_EXCEEDED)

      err
    end
    
    def remove_unfit
      good_parts = []
      must_fit = @leftovers
      must_fit << @options.std_length
      
      @parts.each do |p|
        fits = false
        must_fit.each do |l|
          if p[:length] <= (l -2 * @options.trim_size- 2 * @options.saw_kerf)
            fits = true
            break
          end
        end
        if fits
          good_parts << p
        else
          @unplaced_parts << p
        end
      end
      @parts = good_parts
    end

    def estimate_optimal
      net_length = 0
      @smallest = @options.std_length
      @nb_over_fiftypercent = 0
      @count = 0
      
      @parts.each do |p|
        @total_nb_parts += 1
        net_length += p[:length]
        @count += 1
        @smallest = p[:length] if p[:length] < @smallest
        if p[:length] > 0.5 * (@options.std_length - 2 * @options.trim_size- 2 * @options.saw_kerf)
          @nb_over_fiftypercent += 1
        end
      end

      # we may slightly overestimate the number of kerfs
      net_length += @options.saw_kerf * @count
      # optimal number of bars is computed from net length
      if @options.std_length < EPS
        @opt_nb_bars = @total_nb_parts
      else
        @opt_nb_bars = (net_length / (@options.std_length \
          - 2 * (@options.trim_size+ @options.saw_kerf))).ceil
        # the minimum number of bars will also be larger than the number of bars
        # that are longer than 50% of the std_length
        @opt_nb_bars = [@nb_over_fiftypercent, @opt_nb_bars].max
      end
      return unless @options.debug

      puts('-> estimate optimal')
      print('   smallest = ', to_ls(@smallest), "\n")
      print('   net length = ', to_ls(net_length), ' in ', @opt_nb_bars,
            " bars, over 50\% ", @nb_over_fiftypercent, " parts\n")
    end

    # pack_single takes a single chunk q (of parts MAX_PARTS long)
    # a list of leftovers and a factor
    def pack_single(q, lo, f)
      bars = []

      # q are chunks
      q.each_with_index do |p, i|
        # remove all parts assigned to the last bar so far
        # and add them to the current group
        # this is only used when the input is split into at most
        # MAX_PARTS chunks.
        if (i > 0) && !bars.empty?
          bar = bars.pop
          tmp = []
          #bar.parts.each_with_index do |_e, j|
          #  tmp << [bar.ids[j], bar.parts[j]]
          #end
          bar.parts.each do |b|
            tmp << [b[:id], b[:length]]
          end
          p += tmp
        end
        parts = []
        p.each do |part|
          parts << part[:length]
        end
        until parts.empty?
          if lo.empty?
            if @options.std_length > EPS
              bar = Bar.new(BAR_TYPE_NEW, @options.std_length, @options.trim_size, @options.saw_kerf)
              s = @options.std_length - 2 * @options.trim_size
            else
              # maybe running out of parts
              @unplaced_parts = parts
              return bars, ERROR_NONE
            end
          else
            s = lo.shift
            bar = Bar.new(BAR_TYPE_LO, s, @options.trim_size, @options.saw_kerf)
            s -= 2 * @options.trim_size
          end
          y, y_list = allsubsetsums(parts, s, f)

          # no fitting found
          if y.zero?
            bars << bar if bar.type == BAR_TYPE_LO
            parts = [] if lo.empty? && (@options.std_length <= s)
          else
            # remove ids from p and add them to the bar
            y_list.each do |val|
              i = p.index { |x| x[:length] == val}
              if !i.nil?
                p.delete(i)
                parts.delete_at(parts.index(val) || parts.length)
                #bar.add(i, val) bugfix
                bar.add(p[i][:id], val)
              end
            end
            bars << bar
          end
        end
      end
      [bars, ERROR_NONE]
    end

    def get_tuning(level)
      puts(level)
      case level
      when 1
        [@smallest / 10, @smallest / 5, @smallest / 2,
         0, @smallest, @smallest * 2, @smallest * 5, @smallest * 10]
      when 2
        [@smallest / 10, 0]
      else
        [0]
      end
    end

    def check_optimality
      bars = @bars.sort_by { |b| -b.parts.length }
      bars.each do |b|
        # print(b.parts.to_s, "\n")
        b.result(false)
      end
    end

    # check a posteriori if leftovers can be used
    def check_leftover
      puts('check leftover')
      return if @leftovers.empty?

      return if @options.std_length < EPS

      raw, _net, _leftover = @bars[-1].all_lengths
      if !@leftovers.empty? && (raw <= @leftovers[0])
        @bars[-1].length = @leftovers[0]
        @bars[-1].type = BAR_TYPE_LO
        print('leftover can be used')
      end
    end

    # get the size of the largest leftover
    def get_largest_leftover(bars)
      llo = 0
      bars.each do |b|
        leftover = b.current_leftover
        llo = leftover if leftover > llo
      end
      llo
    end

    def prep_results
      length = 0
      waste = 0
      @bars.each do |b|
        length += b.length
        waste += b.current_leftover
      end
      @efficiency = (length - waste)/length.to_f
    end

    def allsubsetsums(x_list, target, epsilon)
      se = { 0 => [] }
      # sorting or not sorting here? let's not do it
      # x_list = x_list.sort_by {|e| -e}
      max = 0
      x_list.each do |x|
        te = {}
        se.sort.each do |y, y_list|
          next unless y + @options.saw_kerf + x <= target

          sk = @options.saw_kerf
          sk = 0 if y_list.empty?
          te.store(y + x + sk, y_list + [x])
          max = y + x + sk if y + x + sk > max
        end
        # merge te with se, resolve conflicts by
        # keeping the key with the least number of parts
        se.merge!(te) { |_k, v1, v2| v1.length < v2.length ? v1 : v2 }

        # the first max to reach the sum within a term of epsilon
        # (depending on the size of the smallest element) will
        # be returned. this avoids being too greedy!
        next unless max >= target - epsilon

        se = se.sort.to_h
        y = se.keys.last
        y_list = se.values.last
        return y, y_list
      end

      se = se.sort.to_h
      y = se.keys.last
      y_list = se.values.last

      [y, y_list]
    end
  end
end
