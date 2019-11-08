# frozen_string_literal: true

module Ladb
  module OpenCutList
    module BinPacking1D
      require_relative '../../Downloads/v1beta/bar'

      BT_NEW = 0
      BT_LO = 1
      BT_UNFIT = 2

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

      # Packer is the main 1D bin packing algorithm
      class Packer
        attr_accessor :std_bar_length, :leftovers, :trim_size, :saw_kerf,
                      :bar_width, :bar_height, :bars, :unplaced_parts

        def initialize(debug = false)
          @orig_parts = []
          @bar_width = 0
          @bar_height = 0

          @std_bar_length = 0
          @leftovers = []
          @trim_size = 0
          @saw_kerf = 0

          @smallest = 0
          @nb_parts = 0
          @count = 0
          @nb_over_fiftypercent = 0
          @opt_nb_bars = MAX_PARTS

          @bars = []
          @unplaced_parts = []

          @debug = debug
        end

        def estimate_optimal(parts)
          net_length = 0
          @smallest = @std_bar_length
          @nb_over_fiftypercent = 0
          @count = 0
          parts.values.each do |part|
            @nb_parts += 1
            net_length += part
            @count += 1
            @smallest = part if part < @smallest
            if part > 0.5 * (@std_bar_length - 2 * @trim_size - 2 * @saw_kerf)
              @nb_over_fiftypercent += 1
            end
          end

          # we may slightly overestimate the number of kerfs
          net_length += @saw_kerf * @count
          # optimal number of bars is computed from net length
          if @std_bar_length < EPS
            @opt_nb_bars = @nb_parts
          else
            @opt_nb_bars = (net_length / (@std_bar_length - 2 * (@trim_size + @saw_kerf))).ceil
            # the minimum number of bars will also be larger than the number of bars
            # that are longer than 50% of the std_bar_length
            @opt_nb_bars = [@nb_over_fiftypercent, @opt_nb_bars].max
          end
          return unless @debug

          puts('-> estimate optimal')
          print('   smallest = ', @smallest, "\n")
          print('   net length = ', net_length, ' in ', @opt_nb_bars,
                " bars, over 50\% ", @nb_over_fiftypercent, " parts\n")
        end

        def pack(orig_parts, max_seconds = 1)
          return ERROR_NO_PARTS if orig_parts.empty?

          @orig_parts = orig_parts
          parts = orig_parts.clone
          start_time = Time.now if max_seconds

          return ERROR_NO_BINS if (@std_bar_length < EPS) && @leftovers.empty?

          # compute basic statistics to estimate the number of bars needed
          estimate_optimal(parts)
          # split into chunks not larger than MAX_PARTS
          # otherwise it may take forever or be interrupted by timer
          q = parts.each_slice(MAX_PARTS)

          best_bars = []
          best_bars_length = MAX_INT
          opt_found = false
          #
          # compute this 7 times with different epsilon's, keep the best
          #
          begin
            print("-> pack\n") if @debug
            count = 1
            [@smallest / 5, @smallest / 2, @smallest, 0, @smallest, @smallest * 2.5, @smallest * 5].each do |f|
              puts("   pass #{count}") if @debug
              # raise(TimeoutError, "timeout expired") if max_seconds and Time.now - start_time > max_seconds
              lo = @leftovers.clone
              bars, err = packSingle(q, lo, f)
              if err == ERROR_NONE
                if bars.length <= @opt_nb_bars
                  if @debug
                    print("     optimal solution    [#{count}] #{bars.length}\n")
                    end
                  opt_found = true
                end
                if bars.length < best_bars_length
                  print("     updating best bars\n") if @debug
                  best_bars = bars
                  best_bars_length = bars.length
                elsif bars.length == best_bars_length
                  print("     matching best solution so far\n") if @debug
                  if largest_leftover_length(bars) > largest_leftover_length(best_bars)
                    if @debug
                      print("     larger leftover [#{count}] #{bars.length}\n")
                      end
                    best_bars = bars
                    best_bars_length = bars.length
                  else
                    if @debug
                      print("     another solution, but worse leftover\n")
                    end
                  end
                else
                  print("     not getting better pass\n") if @debug
                end
                bars = []
                count += 1
              else
                puts('BIG PROBLEM ', err)
              end
            end
          rescue TimeoutError => e
            if !best_bars.empty?
              @bars = best_bars
              if opt_found
                return ERROR_NONE, best_bars_length
              else
                return ERROR_SUBOPT, best_bars_length
              end
            else
              return ERROR_TIME_EXCEEDED
            end
          end
          @bars = best_bars
          print("-> total time = #{Time.now - start_time}\n") if @debug
          if opt_found
            return ERROR_NONE, best_bars_length
          else
            return ERROR_SUBOPT, best_bars_length
          end
        end

        def packSingle(q, lo, f)
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
                if @std_bar_length > EPS
                  bar = Bar.new(BT_NEW, @std_bar_length, @trim_size, @saw_kerf)
                  s = @std_bar_length - 2 * @trim_size
                else
                  # maybe running out of parts
                  @unplaced_parts = parts
                  return bars, ERROR_NONE
                end
              else
                s = lo.shift
                bar = Bar.new(BT_LO, s, @trim_size, @saw_kerf)
                s -= 2 * @trim_size
              end
              y, y_list = allsubsetsums(parts, s, f)

              # no fitting found
              if y.zero?
                bars << bar if bar.type == BT_LO
                if lo.empty? && (@std_bar_length <= s)
                  parts = []
                end # @std_bar_length <= s
              else
                # remove ids from p and add them to the bar
                # puts(y_list.to_s)
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

        def largest_leftover_length(bars)
          llo = 0
          bars.each do |b|
            _used, _net, leftover = b.length
            llo = leftover if leftover > llo
          end
          llo
        end

        def result(msg = '', with_id = false)
          if @bars.empty?
            print("NO bar available!\n")
            return
          end

          nb_bars = [0, 0, 0]
          lengths = [0, 0, 0, 0]

          print("\nRESULTS: #{msg}\n")
          print("-----------------------------------------------\n")
          print("Type       Bar L    Raw L /   Net L /   Waste\n")
          @bars.each do |bar|
            tmp = bar.result(with_id)
            lengths.each_with_index do |_e, i|
              lengths[i] += tmp[i]
            end
            nb_bars[bar.type] += 1
          end
          print("-----------------------------------------------\n")
          print("Total  [#{'%8.0f' % lengths[0]} ")
          print("#{format('%8.0f', lengths[1])} /#{format('%8.0f', lengths[2])} /#{format('%8.0f', lengths[3])}\n")
          print("-----------------------------------------------\n")
          eff = lengths[2].to_f / lengths[0].to_f * 100
          print("Efficiency  #{format('%.0f', lengths[2])}/#{'%.0f' % lengths[0]} = #{format('%.2f', eff)} \%\n")
          print("Nb parts            : #{@nb_parts}\n")
          print("Placed parts        : #{@nb_parts - @unplaced_parts.length}\n")

          print("Unplaced parts      : #{@unplaced_parts.length}\n")
          print("Total unfit bars    : #{nb_bars[BT_UNFIT]}\n")
          print("Total leftover bars : #{nb_bars[BT_LO]}\n")
          vol = (nb_bars[BT_NEW] * @std_bar_length * @bar_width * @bar_height)
          print("Total new bars      : #{nb_bars[BT_NEW]}\n")
          print("Volume              : #{format('%.3f', vol)} [in units]^3\n")
        end

        def allsubsetsums(x_list, target, epsilon)
          se = { 0 => [] }
          # sorting or not sorting here? let's not do it
          # x_list = x_list.sort_by {|e| -e}
          max = 0
          x_list.each do |x|
            te = {}
            se.sort.each do |y, y_list|
              next unless y + @saw_kerf + x <= target

              sk = @saw_kerf
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
  end
end
