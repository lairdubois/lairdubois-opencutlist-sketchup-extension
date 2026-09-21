module Ladb::OpenCutList

  require_relative '../data_container'

  # A stretch move computed on a StretchSplitDef (see StretchSplitDef#stretch_def) : what
  # CommonStretchApplyWorker applies, and what a tool previews.
  class StretchDef < DataContainer

    attr_reader :split_def,       # StretchSplitDef
                :interior_index,  # Interior handle index, nil for a plain (end grip) stretch
                :factor,          # 2.0 if centered, 1.0 otherwise
                :t_coefs,         # Per section translation coefficients of an interior stretch, nil otherwise
                :emv,             # "Move" vector in edit space (non null if centered)
                :esv,             # "Stretch" vector in edit space
                :edvs,            # SectionDef => move vector of the section, in edit space
                :lps, :lpe        # Measure line start and end, in global space

    def initialize(split_def:, interior_index:, factor:, t_coefs:, emv:, esv:, edvs:, lps:, lpe:)
      @split_def = split_def
      @interior_index = interior_index
      @factor = factor
      @t_coefs = t_coefs
      @emv = emv
      @esv = esv
      @edvs = edvs
      @lps = lps
      @lpe = lpe
    end

    def interior?
      !@interior_index.nil?
    end

    # True if the stretch shrinks the shape along the axis (an interior stretch always compresses
    # gaps on one side, this only tells the way of the move).
    def compressed?
      axis = @split_def.axis
      @esv.valid? && (@split_def.reversed ? @esv.samedirection?(axis) : !@esv.samedirection?(axis))
    end

    # The applied measure : length of the measure line.
    def measure
      @lps.distance(@lpe)
    end

    # -----

    # Preview helpers : the stretched positions of a container def own content, expressed in the
    # EDIT space (render them with the split def 'et' transformation). Children are not included,
    # iterate over 'container_def.children' to walk the tree.

    def preview_edge_segments(container_def)
      container_def.edge_defs.flat_map { |edge_def|
        edge = edge_def.edge
        t = edge_def.transformation
        ti = edge_def.transformation_inverse
        [
          edge.start.position.offset(@edvs[edge_def.start_section_def].transform(ti)).transform(t).offset(@emv),
          edge.end.position.offset(@edvs[edge_def.end_section_def].transform(ti)).transform(t).offset(@emv)
        ]
      }
    end

    def preview_cline_segments(container_def)
      container_def.cline_defs.flat_map { |cline_def|
        cline = cline_def.cline
        t = cline_def.transformation
        ti = cline_def.transformation_inverse
        [
          cline.start.offset(@edvs[cline_def.start_section_def].transform(ti)).transform(t).offset(@emv),
          cline.end.offset(@edvs[cline_def.end_section_def].transform(ti)).transform(t).offset(@emv)
        ]
      }
    end

    def preview_snap_points(container_def)
      container_def.snap_defs.map { |snap_def|
        snap = snap_def.snap
        t = snap_def.transformation
        ti = snap_def.transformation_inverse
        snap.position.offset(@edvs[snap_def.section_def].transform(ti)).transform(t).offset(@emv)
      }
    end

    # -----

    # The cutter ratios - in ]0, 1[ along the stretched bounds - that keep the gaps between the
    # sections once the stretch is applied : the cutters to reuse on the next stretch of the same
    # axis.
    def cutter_ratios
      split_def = @split_def
      et, eps, evpspe, reversed, section_defs = split_def.et, split_def.eps, split_def.evpspe, split_def.reversed, split_def.section_defs

      eti = et.inverse
      if @interior_index.nil?
        epo = reversed ? @lpe.transform(eti) : eps.offset(@emv)
        epomax = reversed ? eps.offset(@emv) : @lpe.transform(eti)
        distance = epo.distance(epomax)
      else
        # An interior stretch preserves the overall dimension : the bbox itself stays the
        # reference, and 'lpe' is on the handle, not on an extremity
        epo = eps
        distance = evpspe.length
      end
      el = [ epo, evpspe ]
      sd = section_defs
      sd = sd.reverse if reversed
      sd.select { |section_def| section_def.bounds.valid? } # Exclude empty sections
        .each_cons(2).map { |section_def0, section_def1|
          max0 = section_def0.bounds.max.project_to_line(el).offset!(@edvs[section_def0] + @emv)
          min1 = section_def1.bounds.min.project_to_line(el).offset!(@edvs[section_def1] + @emv)
          if (v = max0.vector_to(min1)).valid? && v.samedirection?(split_def.axis)  # Exclude if bounds overlap
            epc = Geom.linear_combination(0.5, max0, 0.5, min1)
            epo.vector_to(epc).length / distance
          end
        }
        .compact
    end

  end

end
