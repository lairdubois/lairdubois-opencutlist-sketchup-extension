#include "clipper2/clipper.wrapper.hpp"

#include "nesty.structs.hpp"
#include "nesty.engine.hpp"

#include <algorithm>

#include "packingsolver/rectangle/instance_builder.hpp"
#include "packingsolver/rectangle/optimize.hpp"
#include "packingsolver/rectangleguillotine//instance_builder.hpp"
#include "packingsolver/rectangleguillotine/optimize.hpp"
#include "packingsolver/irregular/instance_builder.hpp"
#include "packingsolver/irregular/optimize.hpp"

using namespace Clipper2Lib;
using namespace packingsolver;
using namespace packingsolver::rectangle;
using namespace packingsolver::rectangleguillotine;
using namespace packingsolver::irregular;

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
//    return v;
    return v / 1e6;
  }

  int64_t VToInt64(int64_t i) {
//    return i;
    return i * 1e6;
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

  bool RectangleEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution) {

    rectangle::InstanceBuilder instance_builder;
    instance_builder.set_objective(Objective::VariableSizedBinPacking);

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
    parameters.timer.set_time_limit(10);
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

  bool RectangleGuillotineEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution) {

    rectangleguillotine::InstanceBuilder instance_builder;
    instance_builder.set_objective(Objective::VariableSizedBinPacking);
    instance_builder.set_cut_thickness(Int64ToV(spacing));
    instance_builder.set_first_stage_orientation(rectangleguillotine::CutOrientation::Horizontal);

    for (auto &bin_def: bin_defs) {

      bin_def.bin_type_id = instance_builder.add_bin_type(
              Int64ToV(bin_def.length),
              Int64ToV(bin_def.width),
              -1,
              bin_def.count
      );

//      instance_builder.add_trims(
//              bin_def.bin_type_id,
//              Int64ToV(trimming),
//              rectangleguillotine::TrimType::Hard,
//              Int64ToV(trimming),
//              rectangleguillotine::TrimType::Soft,
//              Int64ToV(trimming),
//              rectangleguillotine::TrimType::Hard,
//              Int64ToV(trimming),
//              rectangleguillotine::TrimType::Soft
//      );

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

    rectangleguillotine::Instance instance = instance_builder.build();

    rectangleguillotine::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytimeSequential;
    parameters.timer.set_time_limit(10);
    parameters.verbosity_level = 3;
    parameters.not_anytime_tree_search_queue_size = 64;

    const rectangleguillotine::Output output = rectangleguillotine::optimize(instance, parameters);
    const rectangleguillotine::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const rectangleguillotine::SolutionBin &ps_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = ps_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < ps_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (SolutionNodeId node_id = 0; node_id < (SolutionNodeId)ps_bin.nodes.size(); ++node_id) {

            const SolutionNode &ps_node = ps_bin.nodes[node_id];

            ItemTypeId item_type_id = ps_node.item_type_id;

            auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(),
                                             [&item_type_id](const ShapeDef &shape_def) {
                                               return shape_def.item_type_id == item_type_id;
                                             });
            if (shape_def_it != shape_defs.end()) {

              Shape &shape = bin.shapes.emplace_back(&*shape_def_it);
              shape.x = VToInt64(ps_node.l);
              shape.y = VToInt64(ps_node.b);
              shape.angle = 0;

            }

          }

        }

      }

    }

    return true;
  }

  bool IrregularEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution) {

    solution.clear();

    irregular::InstanceBuilder instance_builder;
    instance_builder.set_objective(Objective::BinPacking);

    for (auto &bin_def: bin_defs) {

      LengthDbl length = (LengthDbl) Int64ToV(bin_def.length);
      LengthDbl width = (LengthDbl) Int64ToV(bin_def.width);

      irregular::Shape shape;

      irregular::ShapeElement element_1;
      irregular::ShapeElement element_2;
      irregular::ShapeElement element_3;
      irregular::ShapeElement element_4;
      element_1.type = irregular::ShapeElementType::LineSegment;
      element_2.type = irregular::ShapeElementType::LineSegment;
      element_3.type = irregular::ShapeElementType::LineSegment;
      element_4.type = irregular::ShapeElementType::LineSegment;
      element_1.start = {0.0, 0.0};
      element_1.end = {length, 0.0};
      element_2.start = {length, 0.0};
      element_2.end = {length, width};
      element_3.start = {length, width};
      element_3.end = {0.0, width};
      element_4.start = {0.0, width};
      element_4.end = {0.0, 0.0};
      shape.elements.push_back(element_1);
      shape.elements.push_back(element_2);
      shape.elements.push_back(element_3);
      shape.elements.push_back(element_4);

      bin_def.bin_type_id = instance_builder.add_bin_type(
              shape,
              -1,
              bin_def.count
      );

    }

    for (auto &shape_def: shape_defs) {

      std::vector <irregular::ItemShape> item_shapes;

      for (auto &path: shape_def.paths) {

        irregular::ItemShape item_shape;

        for (auto point_it = begin(path); point_it != end(path); ++point_it) {

          auto point_it_next = point_it + 1;
          if (point_it_next == end(path)) {
            point_it_next = begin(path);
          }

          LengthDbl xs = (LengthDbl) Int64ToV((*point_it).x);
          LengthDbl ys = (LengthDbl) Int64ToV((*point_it).y);
          LengthDbl xe = (LengthDbl) Int64ToV((*point_it_next).x);
          LengthDbl ye = (LengthDbl) Int64ToV((*point_it_next).y);

          irregular::ShapeElement line;
          line.type = irregular::ShapeElementType::LineSegment;
          line.start = {xs, ys};
          line.end = {xe, ye};
          item_shape.shape.elements.push_back(line);

        }

        item_shapes.push_back(item_shape);

        break;   // TODO add holes
      }

      shape_def.item_type_id = instance_builder.add_item_type(
              item_shapes,
              -1,
              shape_def.count
      );

    }

    irregular::Instance instance = instance_builder.build();

    irregular::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytimeSequential;
    parameters.timer.set_time_limit(10);
    parameters.verbosity_level = 3;
    parameters.not_anytime_tree_search_queue_size = 512;

    const irregular::Output output = irregular::optimize(instance, parameters);
    const irregular::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const irregular::SolutionBin &ps_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = ps_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

        for (auto &ps_item: ps_bin.items) {

          ItemTypeId item_type_id = ps_item.item_type_id;

          auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(),
                                           [&item_type_id](const ShapeDef &shape_def) {
                                             return shape_def.item_type_id == item_type_id;
                                           });
          if (shape_def_it != shape_defs.end()) {

            Shape &shape = bin.shapes.emplace_back(&*shape_def_it);
            shape.x = VToInt64(ps_item.bl_corner.x);
            shape.y = VToInt64(ps_item.bl_corner.y);
            shape.angle = (int64_t) ps_item.angle;

          }

        }

      }

    }

    return true;
  }

}