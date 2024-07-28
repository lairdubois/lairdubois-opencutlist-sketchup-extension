#include "clipper2/clipper.wrapper.hpp"

#include "packy.structs.hpp"
#include "packy.engine.hpp"

#include <algorithm>
#include <stack>

#include "packingsolver/rectangle/instance_builder.hpp"
#include "packingsolver/rectangle/optimize.hpp"
#include "packingsolver/rectangleguillotine/instance_builder.hpp"
#include "packingsolver/rectangleguillotine/optimize.hpp"
#include "packingsolver/irregular/instance_builder.hpp"
#include "packingsolver/irregular/optimize.hpp"
#include "packingsolver/onedimensional/instance_builder.hpp"
#include "packingsolver/onedimensional/optimize.hpp"

using namespace Clipper2Lib;
using namespace packingsolver;
using namespace packingsolver::rectangle;
using namespace packingsolver::rectangleguillotine;
using namespace packingsolver::irregular;
using namespace packingsolver::onedimensional;

namespace Packy {

  // Clipper2 documentation : https://angusj.com/clipper2/Docs/Overview.htm

  inline bool item_sorter(Item &item1, Item &item2) {
    return (GetBounds(item1.def->paths).Height() > GetBounds(item2.def->paths).Height());
  }

  inline bool bins_sorter(Bin &bin1, Bin &bin2) {
    if (bin1.def->type == bin2.def->type) {
      return (bin1.def->length * bin1.def->width < bin2.def->length * bin2.def->width);
    }
    return (bin1.def->type > bin2.def->type);
  }

  inline void convert_path_to_shape(const PathD& path, irregular::Shape& shape) {
    for (auto point_it = begin(path); point_it != end(path); ++point_it) {

      auto point_it_next = point_it + 1;
      if (point_it_next == end(path)) {
        point_it_next = begin(path);
      }

      LengthDbl xs = (LengthDbl)(*point_it).x;
      LengthDbl ys = (LengthDbl)(*point_it).y;
      LengthDbl xe = (LengthDbl)(*point_it_next).x;
      LengthDbl ye = (LengthDbl)(*point_it_next).y;

      irregular::ShapeElement line;
      line.type = irregular::ShapeElementType::LineSegment;
      line.start = {xs, ys };
      line.end = {xe, ye };
      shape.elements.push_back(line);

    }
  }

  bool RectangleEngine::run(
          ItemDefs &item_defs,
          BinDefs &bin_defs,
          char *c_objective,
          double c_spacing,
          double c_trimming,
          int verbosity_level,
          Solution &solution,
          std::string &message) {

    solution.clear();
    message.clear();

    packingsolver::Objective objective;
    std::stringstream ss_objective(c_objective);
    ss_objective >> objective;

    packingsolver::Length spacing = c_spacing;
    packingsolver::Length trimming = c_trimming;

    rectangle::InstanceBuilder instance_builder;
    instance_builder.set_objective(objective);

    for (auto &bin_def: bin_defs) {

      bin_def.bin_type_id = instance_builder.add_bin_type(
              bin_def.length - trimming * 2 + spacing,
              bin_def.width - trimming * 2 + spacing,
              -1,
              bin_def.count
      );

    }

    for (auto &item_def: item_defs) {

      RectD bounds = GetBounds(item_def.paths);

      item_def.item_type_id = instance_builder.add_item_type(
              bounds.Width() + spacing,
              bounds.Height() + spacing,
              -1,
              item_def.count,
              item_def.rotations == 0
      );

    }

    rectangle::Instance instance = instance_builder.build();

    rectangle::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytime;
    parameters.not_anytime_tree_search_queue_size = 1024;
    parameters.timer.set_time_limit(5);
    parameters.verbosity_level = verbosity_level;

    const rectangle::Output output = rectangle::optimize(instance, parameters);
    const rectangle::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const rectangle::SolutionBin &solution_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = solution_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto item_def_it = std::find_if(item_defs.begin(), item_defs.end(),
                                             [&item_type_id](const ItemDef &item_def) {
                                               return item_def.item_type_id == item_type_id;
                                             });
            if (item_def_it != item_defs.end()) {

              ItemDef &item_def = *item_def_it;
              RectD bounds = GetBounds(item_def.paths);

              Item &item = bin.items.emplace_back(&item_def);
              if (solution_item.rotate) {
                item.x = trimming + solution_item.bl_corner.x + bounds.Height();
                item.y = trimming + solution_item.bl_corner.y;
                item.angle = 90;
              } else {
                item.x = trimming + solution_item.bl_corner.x;
                item.y = trimming + solution_item.bl_corner.y;
                item.angle = 0;
              }

            }

          }

        }

      }

    }

    std::stringstream ss;

    ss << "ENGINE --------------------------" << std::endl;
    ss << "Rectangle" << std::endl;
    ss << std::endl << "INSTANCE ------------------------" << std::endl;
    instance.format(ss, parameters.verbosity_level);
    ss << std::endl << "PARAMETERS ----------------------" << std::endl;
    parameters.format(ss);
    ss << std::endl << "SOLUTION ------------------------" << std::endl;
    ss << "Elapsed time: " << parameters.timer.elapsed_time() << std::endl;
    ps_solution.format(ss, parameters.verbosity_level);

    message = ss.str();

    return true;
  }

  bool RectangleGuillotineEngine::run(
          ItemDefs &item_defs,
          BinDefs &bin_defs,
          char *c_objective,
          char *c_cut_type,
          char *c_first_stage_orientation,
          double c_spacing,
          double c_trimming,
          int verbosity_level,
          Solution &solution,
          std::string &message) {

    solution.clear();
    message.clear();

    packingsolver::Objective objective;
    std::stringstream ss_objective(c_objective);
    ss_objective >> objective;

    packingsolver::rectangleguillotine::CutType cut_type;
    std::stringstream ss_cut_type(c_cut_type);
    ss_cut_type >> cut_type;

    packingsolver::rectangleguillotine::CutOrientation first_stage_orientation;
    std::stringstream ss_first_stage_orientation(c_first_stage_orientation);
    ss_first_stage_orientation >> first_stage_orientation;

    packingsolver::Length spacing = c_spacing;
    packingsolver::Length trimming = c_trimming;

    rectangleguillotine::InstanceBuilder instance_builder;
    instance_builder.set_objective(objective);
    instance_builder.set_cut_type(cut_type);
    instance_builder.set_first_stage_orientation(first_stage_orientation);
    instance_builder.set_cut_thickness(spacing);

    for (auto &bin_def: bin_defs) {

      bin_def.bin_type_id = instance_builder.add_bin_type(
              bin_def.length,
              bin_def.width,
              -1,
              bin_def.count
      );

      instance_builder.add_trims(
              bin_def.bin_type_id,
              trimming,
              rectangleguillotine::TrimType::Hard,
              trimming,
              rectangleguillotine::TrimType::Soft,
              trimming,
              rectangleguillotine::TrimType::Hard,
              trimming,
              rectangleguillotine::TrimType::Soft
      );

    }

    for (auto &item_def: item_defs) {

      RectD bounds = GetBounds(item_def.paths);

      item_def.item_type_id = instance_builder.add_item_type(
              bounds.Width(),
              bounds.Height(),
              -1,
              item_def.count,
              item_def.rotations == 0
      );

    }

    rectangleguillotine::Instance instance = instance_builder.build();

    //    instance.write("./test");

    rectangleguillotine::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytime;
    parameters.not_anytime_tree_search_queue_size = 1024;
    parameters.timer.set_time_limit(5);
    parameters.verbosity_level = verbosity_level;

    const rectangleguillotine::Output output = rectangleguillotine::optimize(instance, parameters);
    const rectangleguillotine::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const rectangleguillotine::SolutionBin &solution_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = solution_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (SolutionNodeId node_id = 0; node_id < (SolutionNodeId) solution_bin.nodes.size(); ++node_id) {

            const SolutionNode &solution_node = solution_bin.nodes[node_id];

            ItemTypeId item_type_id = solution_node.item_type_id;

            auto item_def_it = std::find_if(item_defs.begin(), item_defs.end(),
                                             [&item_type_id](const ItemDef &item_def) {
                                               return item_def.item_type_id == item_type_id;
                                             });
            if (item_def_it != item_defs.end()) {

              ItemDef &item_def = *item_def_it;
              RectD bounds = GetBounds(item_def.paths);
              bool rotated = bounds.Width() != (solution_node.r - solution_node.l);

              Item &item = bin.items.emplace_back(&item_def);
              if (rotated) {
                item.x = solution_node.r;
                item.y = solution_node.b;
                item.angle = 90;
              } else {
                item.x = solution_node.l;
                item.y = solution_node.b;
                item.angle = 0;
              }

            }

            if (item_type_id >= 0 || !solution_node.children.empty()) {

              if (solution_node.d == 0) {

                if (trimming > 0) {

                  // Bottom
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.l - (first_stage_orientation ==
                                                           rectangleguillotine::CutOrientation::Horizontal
                                                           ? trimming : 0),
                                        solution_node.b - spacing,
                                        solution_node.r + trimming,
                                        solution_node.b);

                  // Left
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.l - spacing,
                                        solution_node.b - (first_stage_orientation ==
                                                           rectangleguillotine::CutOrientation::Vertical
                                                           ? trimming : 0),
                                        solution_node.l,
                                        solution_node.t + trimming);

                }

              } else if (solution_node.f >= 0) {

                const SolutionNode &parent_solution_node = solution_bin.nodes[solution_node.f];

                if (solution_node.r != parent_solution_node.r) {
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.r,
                                        solution_node.b,
                                        solution_node.r + spacing,
                                        solution_node.t + (solution_node.d == 1 ? trimming : 0));
                }
                if (solution_node.t != parent_solution_node.t) {
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.l,
                                        solution_node.t,
                                        solution_node.r + (solution_node.d == 1 ? trimming : 0),
                                        solution_node.t + spacing);
                }

              }

            }

          }

        }

      }

    }

    std::stringstream ss;

    ss << "ENGINE --------------------------" << std::endl;
    ss << "RectangleGuillotine" << std::endl;
    ss << std::endl << "INSTANCE ------------------------" << std::endl;
    instance.format(ss, parameters.verbosity_level);
    ss << std::endl << "PARAMETERS ----------------------" << std::endl;
    parameters.format(ss);
    ss << std::endl << "SOLUTION ------------------------" << std::endl;
    ss << "Elapsed time: " << parameters.timer.elapsed_time() << std::endl;
    ps_solution.format(ss, parameters.verbosity_level);

    message = ss.str();

    return true;
  }

  bool IrregularEngine::run(
          ItemDefs &item_defs,
          BinDefs &bin_defs,
          char *c_objective,
          double c_spacing,
          double c_trimming,
          int verbosity_level,
          Solution &solution,
          std::string &message) {

    solution.clear();
    message.clear();

    packingsolver::Objective objective;
    std::stringstream ss_objective(c_objective);
    ss_objective >> objective;

    packingsolver::Length spacing = c_spacing;
    packingsolver::Length trimming = c_trimming;

    irregular::InstanceBuilder instance_builder;
    instance_builder.set_objective(objective);

    for (auto &bin_def: bin_defs) {

      LengthDbl length = (LengthDbl) bin_def.length - 2 * trimming;
      LengthDbl width = (LengthDbl) bin_def.width - 2 * trimming;

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

    for (auto &item_def: item_defs) {

      // Using Clipper2 to compute polygons tree
      PolyTreeD polytree;
      ClipperD clipper;
      clipper.AddSubject(item_def.paths);
      clipper.PreserveCollinear(false);
      clipper.Execute(ClipType::Union, FillRule::NonZero, polytree);

      // Convert polygons tree to PackingSolver item shapes
      std::vector<irregular::ItemShape> item_shapes;

      std::stack<const PolyPathD*> stack;
      for (const auto& child : polytree) {
        stack.push(&*child);
      }

      while (!stack.empty()) {

        const PolyTreeD& current = *(stack.top());
        stack.pop();

        // Iterate over children
        for (const auto& child : current) {
          stack.push(&*child);
        }

        if (current.IsHole()) {

          // Handle hole case (add to last item_shape if not empty)

          if (!item_shapes.empty()) {

            PathD path = current.Polygon();
            std::reverse(path.begin(), path.end()); // Clipper2 holes must be reversed
            irregular::Shape shape;
            convert_path_to_shape(path, shape);

            irregular::ItemShape& item_shape = item_shapes.back();
            item_shape.holes.push_back(shape);

          }

        } else {

          // Create a new ItemShape for non-hole paths

          irregular::ItemShape item_shape;
          convert_path_to_shape(current.Polygon(), item_shape.shape);

          item_shapes.push_back(item_shape);

        }

      }

      item_def.item_type_id = instance_builder.add_item_type(
              item_shapes,
              -1,
              item_def.count,
              {{0, 0}}
      );

    }

    irregular::Instance instance = instance_builder.build();

//    instance.write("./test");

    irregular::OptimizeParameters parameters;

    parameters.optimization_mode = OptimizationMode::NotAnytime;
    parameters.not_anytime_tree_search_queue_size = 512;
    parameters.timer.set_time_limit(100);
    parameters.verbosity_level = verbosity_level;

    const irregular::Output output = irregular::optimize(instance, parameters);
    const irregular::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const irregular::SolutionBin &solution_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = solution_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) { return bin_def.bin_type_id == bin_type_id; });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto item_def_it = std::find_if(item_defs.begin(), item_defs.end(), [&item_type_id](const ItemDef &item_def) { return item_def.item_type_id == item_type_id; });
            if (item_def_it != item_defs.end()) {

              Item &item = bin.items.emplace_back(&*item_def_it);
              item.x = solution_item.bl_corner.x + trimming;
              item.y = solution_item.bl_corner.y + trimming;
              item.angle = (int64_t) solution_item.angle;

            }

          }

        }

      }

    }

    std::stringstream ss;

    ss << "ENGINE --------------------------" << std::endl;
    ss << "Irregular" << std::endl;
    ss << std::endl << "INSTANCE ------------------------" << std::endl;
    instance.format(ss, verbosity_level);
    ss << std::endl << "PARAMETERS ----------------------" << std::endl;
    parameters.format(ss);
    ss << std::endl << "SOLUTION ------------------------" << std::endl;
    ss << "Elapsed time: " << parameters.timer.elapsed_time() << std::endl;
    ps_solution.format(ss, verbosity_level);

    message = ss.str();

    return true;
  }

  bool OneDimensionalEngine::run(
          ItemDefs &item_defs,
          BinDefs &bin_defs,
          char *c_objective,
          double c_spacing,
          double c_trimming,
          int verbosity_level,
          Solution &solution,
          std::string &message) {

    solution.clear();
    message.clear();

    packingsolver::Objective objective;
    std::stringstream ss_objective(c_objective);
    ss_objective >> objective;

    packingsolver::Length spacing = c_spacing;
    packingsolver::Length trimming = c_trimming;

    onedimensional::InstanceBuilder instance_builder;
    instance_builder.set_objective(objective);

    for (auto &bin_def: bin_defs) {

      bin_def.bin_type_id = instance_builder.add_bin_type(
              bin_def.length - trimming * 2 + spacing,
              -1,
              bin_def.count
      );

    }

    for (auto &item_def: item_defs) {

      RectD bounds = GetBounds(item_def.paths);

      item_def.item_type_id = instance_builder.add_item_type(
              bounds.Width() + spacing,
              -1,
              item_def.count
      );

    }

    onedimensional::Instance instance = instance_builder.build();

    //    instance.write("./test");

    onedimensional::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytime;
    parameters.not_anytime_tree_search_queue_size = 1024;
    parameters.timer.set_time_limit(5);
    parameters.verbosity_level = verbosity_level;

    const onedimensional::Output output = onedimensional::optimize(instance, parameters);
    const onedimensional::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const onedimensional::SolutionBin &solution_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = solution_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto item_def_it = std::find_if(item_defs.begin(), item_defs.end(),
                                             [&item_type_id](const ItemDef &item_def) {
                                               return item_def.item_type_id == item_type_id;
                                             });
            if (item_def_it != item_defs.end()) {

              Item &item = bin.items.emplace_back(&*item_def_it);
              item.x = trimming + solution_item.start;
              item.y = 0;
              item.angle = 0;

            }

          }

        }

      }

    }

    std::stringstream ss;

    ss << "ENGINE --------------------------" << std::endl;
    ss << "OneDimensional" << std::endl;
    ss << std::endl << "INSTANCE ------------------------" << std::endl;
    instance.format(ss, parameters.verbosity_level);
    ss << std::endl << "PARAMETERS ----------------------" << std::endl;
    parameters.format(ss);
    ss << std::endl << "SOLUTION ------------------------" << std::endl;
    ss << "Elapsed time: " << parameters.timer.elapsed_time() << std::endl;
    ps_solution.format(ss, parameters.verbosity_level);

    message = ss.str();

    return true;
  }

}