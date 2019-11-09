module Ladb::OpenCutList::BinPacking1D
  
  require_relative 'bar'
  require_relative 'options'
  require_relative 'result'

  BAR_TYPE_NEW = 0
  BAR_TYPE_LO = 1
  BAR_TYPE_UNFIT = 2

  ERROR_NONE = 0
  ERROR_SUBOPT = 1
  ERROR_NO_BINS = 2
  ERROR_NO_PLACEMENT_POSSIBLE = 3
  ERROR_BAD_ERROR = 4
  ERROR_TIME_EXCEEDED = 5
  ERROR_NO_PARTS = 6

  MAX_PARTS = 205

  N_BYTES = [42].pack('i').size
  N_BITS = N_BYTES * 16
  MAX_INT = 2**(N_BITS - 2) - 1
  EPS = 1e-9

  # Used by Timer for execution of algorithm
  class TimeoutError < StandardError
  end

  class Packing1D
    attr_accessor :options, :std_length, 
                  :bars, :leftovers, :unplaced_parts, 
                  :nb_parts

    def initialize(options, _debug = false)
      @orig_parts = Hash.new
      @options = options
      @leftovers = []

      @smallest = 0
      @nb_parts = 0
      @count = 0
      @nb_over_fiftypercent = 0
      @opt_nb_bars = MAX_PARTS

      @bars = []
      @parts = {}
      @unplaced_parts = []

    end

    def add_bin(length)
      @leftovers << length
    end

    def add_part(length, data=nil)
      @orig_parts[data] = length unless @orig_parts.key?(data)
    end

    def run
      err = ERROR_NONE

      return ERROR_NO_PARTS if @orig_parts.empty?

      parts = @orig_parts.clone
      start_time = Time.now if @options.max_time

      return ERROR_NO_BINS if @options.std_length < EPS && @leftovers.empty?

      # compute basic statistics to estimate the number of bars needed
      estimate_optimal(parts)
      # split into chunks not larger than MAX_PARTS
      # otherwise it may take forever or be interrupted by timer
      q = parts.each_slice(MAX_PARTS)

      best_bars = []
      best_bars_length = MAX_INT
      llo_bars = 0
      opt_found = false
      #
      # compute this 7 times with different epsilon's, keep the best
      #
      begin
        print("-> pack\n") if @options.debug
        count = 1
        t = get_tuning(@options.tuning_factor)
        t.each do |f|
          puts("   pass #{count}") if @options.debug
          if @options.max_time && (Time.now - start_time > @options.max_time)
            puts('timeout... why?')
            raise(TimeoutError, 'timeout expired')
          end

          lo = @leftovers.clone
          if @options.std_length < EPS
            bars, err = pack_single(q, lo, f)
          else
            bars, err = pack_single(q, [], f)
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
            lo_bars = get_leftover_length(bars)
            if bars.length < best_bars_length
              best_bars = bars
              best_bars_length = bars.length
              llo_bars = lo_bars
              if @options.debug
                print("     [#{count}]: better best bars #{bars.length}, leftover #{llo_bars.to_l.to_s}\n")
              end
            elsif (bars.length == best_bars_length) && (lo_bars > llo_bars)
              best_bars = bars
              best_bars_length = bars.length
              llo_bars = lo_bars
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

    def estimate_optimal(parts)
      net_length = 0
      @smallest = @options.std_length
      @nb_over_fiftypercent = 0
      @count = 0
      parts.values.each do |part|
        @nb_parts += 1
        net_length += part
        @count += 1
        @smallest = part if part < @smallest
        if part > 0.5 * (@options.std_length - 2 * @options.trim_size- 2 * @options.saw_kerf)
          @nb_over_fiftypercent += 1
        end
      end

      # we may slightly overestimate the number of kerfs
      net_length += @options.saw_kerf * @count
      # optimal number of bars is computed from net length
      if @options.std_length < EPS
        @opt_nb_bars = @nb_parts
      else
        @opt_nb_bars = (net_length / (@options.std_length \
        - 2 * (@options.trim_size+ @options.saw_kerf))).ceil
        # the minimum number of bars will also be larger than the number of bars
        # that are longer than 50% of the std_bar_length
        @opt_nb_bars = [@nb_over_fiftypercent, @opt_nb_bars].max
      end
      return unless @options.debug

      puts('-> estimate optimal')
      print('   smallest = ', @smallest.to_l.to_s, "\n")
      print('   net length = ', net_length.to_l.to_s, ' in ', @opt_nb_bars,
            " bars, over 50\% ", @nb_over_fiftypercent, " parts\n")
    end

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
          bar.parts.each_with_index do |_e, j|
            tmp << [bar.ids[j], bar.parts[j]]
          end
          p += tmp
        end
        p = Hash[p]
        parts = p.values
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
              i = p.key(val)
              p.delete(i)
              parts.delete_at(parts.index(val) || parts.length)
              bar.add(i, val)
            end
            bars << bar
          end
        end
      end
      [bars, ERROR_NONE]
    end

    def get_tuning(factor)
      case factor
      when 1
        [@smallest / 10, @smallest / 5, @smallest / 2, @smallest,
         0, @smallest, @smallest * 2, @smallest * 5, @smallest * 10]
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

      raw, _net, _leftover = @bars[-1].length
      if !@leftovers.empty? && (raw <= @leftovers[0])
        @bars[-1].length = @leftovers[0]
        @bars[-1].type = BAR_TYPE_LO
        print('leftover can be used')
      end
    end

    # get the size of the leftover
    def get_leftover_length(bars)
      llo = 0
      bars.each do |b|
        _raw, _net, leftover = b.length
        llo = leftover if leftover > llo
      end
      llo
    end

    def result(msg = '', with_id = false)
      result = Result.new
      result.prt_summary(self, msg, with_id)
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
