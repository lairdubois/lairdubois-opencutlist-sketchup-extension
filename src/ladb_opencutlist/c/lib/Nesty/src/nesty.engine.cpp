#include "clipper2/clipper.wrapper.h"

#include "nesty.structs.h"
#include "nesty.engine.h"

#include <algorithm>
#include <string>

using namespace Clipper2Lib;

namespace Nesty {

  // Clipper2 documentation : https://angusj.com/clipper2/Docs/Overview.htm

  inline bool shapes_sorter(Shape &shape1, Shape &shape2) {
    return (GetBounds(shape1.def->paths).Height() < GetBounds(shape2.def->paths).Height());
  }
  inline bool bins_sorter(Bin &bin1, Bin &bin2) {
    if (bin1.def->type == bin2.def->type) {
      return (bin1.def->length * bin1.def->width < bin2.def->length * bin2.def->width);
    }
    return (bin1.def->type > bin2.def->type);
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

}