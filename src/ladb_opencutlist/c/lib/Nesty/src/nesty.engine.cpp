#include "clipper2/clipper.wrapper.hpp"

#include "nesty.structs.hpp"
#include "nesty.engine.hpp"

#include <algorithm>

#include "packingsolver/rectangle/instance_builder.hpp"
#include "packingsolver/rectangle/optimize.hpp"
#include "packingsolver/rectangleguillotine/instance_builder.hpp"
#include "packingsolver/rectangleguillotine/optimize.hpp"

using namespace Clipper2Lib;
using namespace packingsolver;
using namespace packingsolver::rectangle;
using namespace packingsolver::rectangleguillotine;

namespace Nesty {

  // Clipper2 documentation : https://angusj.com/clipper2/Docs/Overview.htm

  inline bool shapes_sorter(Shape &shape1, Shape &shape2) {
    return (GetBounds(shape1.def->paths).Height() > GetBounds(shape2.def->paths).Height());
  }
  inline bool bins_sorter(Bin &bin1, Bin &bin2) {
    if (bin1.def->type == bin2.def->type) {
      return (bin1.def->length * bin1.def->width < bin2.def->length * bin2.def->width);
    }
    return (bin1.def->type > bin2.def->type);
  }

  int64_t Int64ToV(int64_t v) {
    return v / 1e4;
  }

  int64_t VToInt64(int64_t i) {
    return i * 1e4;
  }


  bool DummyEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution) {

    solution.clear();

    for (auto &shape_def: shape_defs) {
      for (int i = 0; i < shape_def.count; ++i) {
        solution.unplaced_shapes.emplace_back(&shape_def);
      }
    }
    std::sort(solution.unplaced_shapes.begin(), solution.unplaced_shapes.end(), shapes_sorter);

    for (auto &bin_def: bin_defs) {
      for (int i = 0; i < bin_def.count; ++i) {
        solution.unused_bins.emplace_back(&bin_def);
      }
    }
    std::sort(solution.unused_bins.begin(), solution.unused_bins.end(), bins_sorter);

    for (auto bin_it = begin(solution.unused_bins); bin_it != end(solution.unused_bins);) {

      int64_t min_x = trimming;
      int64_t max_x = bin_it->def->length - trimming;
      int64_t min_y = trimming;
      int64_t max_y = bin_it->def->width - trimming;
      int64_t x = min_x;
      int64_t y = min_y;
      int64_t row_height = 0;

      for (auto shape_it = begin(solution.unplaced_shapes); shape_it != end(solution.unplaced_shapes);) {

        Rect64 bounds = GetBounds(shape_it->def->paths);
        if (y + bounds.Height() > max_y) {
          shape_it++;
          continue;
        };
        if (x + bounds.Width() > max_x) {
          x = min_x;
          y += row_height + spacing;
          row_height = 0;
          continue;
        }

        shape_it->x = x;
        shape_it->y = y;

        x += bounds.Width() + spacing;
        row_height = std::max(row_height, bounds.Height());

        bin_it->shapes.push_back(*shape_it);
        solution.unplaced_shapes.erase(shape_it);

      }

      if (!bin_it->shapes.empty()) {
        solution.packed_bins.push_back(*bin_it);
        solution.unused_bins.erase(bin_it);
      } else {
        bin_it++;
      }
      if (solution.unplaced_shapes.empty()) break;

    }

    return true;
  }

  bool PackingSolverEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution) {

    solution.clear();


    // Rectangle /////

    rectangle::InstanceBuilder instance_builder;
    instance_builder.set_objective(Objective::BinPacking);

    for (auto &bin_def: bin_defs) {

      bin_def.bin_type_id = instance_builder.add_bin_type(
              Int64ToV(bin_def.length),
              Int64ToV(bin_def.width),
              -1,
              bin_def.count
      );

    }

    for (auto &shape_def: shape_defs) {

      Rect64 bounds = GetBounds(shape_def.paths);

      shape_def.item_type_id = instance_builder.add_item_type(
              Int64ToV(bounds.Width()),
              Int64ToV(bounds.Height()),
              -1,
              shape_def.count,
              true
      );

    }

    rectangle::Instance instance = instance_builder.build();

    rectangle::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytimeSequential;
    parameters.timer.set_time_limit(5);
    parameters.verbosity_level = 3;

    const rectangle::Output output = rectangle::optimize(instance, parameters);
    const rectangle::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const rectangle::SolutionBin &ps_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = ps_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) { return bin_def.bin_type_id == bin_type_id; });
      if (bin_def_it != bin_defs.end()) {

        Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

        for (auto &ps_item: ps_bin.items) {

          ItemTypeId item_type_id = ps_item.item_type_id;

          auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(), [&item_type_id](const ShapeDef &shape_def) { return shape_def.item_type_id == item_type_id; });
          if (shape_def_it != shape_defs.end()) {

            Shape &shape = bin.shapes.emplace_back(&*shape_def_it);
            shape.x = VToInt64(ps_item.bl_corner.x);
            shape.y = VToInt64(ps_item.bl_corner.y);
            shape.angle = 0;

          }

        }

      }

    }

    return true;
  }

}