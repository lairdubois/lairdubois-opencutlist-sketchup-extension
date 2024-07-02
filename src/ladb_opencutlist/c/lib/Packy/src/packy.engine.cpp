#include "clipper2/clipper.wrapper.hpp"

#include "packy.structs.hpp"
#include "packy.engine.hpp"

#include <algorithm>

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

  inline bool shapes_sorter(Shape &shape1, Shape &shape2) {
    return (GetBounds(shape1.def->paths).Height() > GetBounds(shape2.def->paths).Height());
  }
  inline bool bins_sorter(Bin &bin1, Bin &bin2) {
    if (bin1.def->type == bin2.def->type) {
      return (bin1.def->length * bin1.def->width < bin2.def->length * bin2.def->width);
    }
    return (bin1.def->type > bin2.def->type);
  }

  bool RectangleEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, char *c_objective, int64_t c_spacing, int64_t c_trimming, int verbosity_level, Solution &solution, std::string &message) {

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

    for (auto &shape_def: shape_defs) {

      Rect64 bounds = GetBounds(shape_def.paths);

      shape_def.item_type_id = instance_builder.add_item_type(
              bounds.Width() + spacing,
              bounds.Height() + spacing,
              -1,
              shape_def.count,
              shape_def.rotations == 0
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

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) { return bin_def.bin_type_id == bin_type_id; });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(), [&item_type_id](const ShapeDef &shape_def) { return shape_def.item_type_id == item_type_id; });
            if (shape_def_it != shape_defs.end()) {

              ShapeDef &shape_def = *shape_def_it;
              Rect64 bounds = GetBounds(shape_def.paths);

              Shape &shape = bin.shapes.emplace_back(&shape_def);
              if (solution_item.rotate) {
                shape.x = trimming + solution_item.bl_corner.x + bounds.Height();
                shape.y = trimming + solution_item.bl_corner.y;
                shape.angle = 90;
              } else {
                shape.x = trimming + solution_item.bl_corner.x;
                shape.y = trimming + solution_item.bl_corner.y;
                shape.angle = 0;
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

  bool RectangleGuillotineEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, char *c_objective, char *c_cut_type, char *c_first_stage_orientation, int64_t c_spacing, int64_t c_trimming, int verbosity_level, Solution &solution, std::string &message) {

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

    for (auto &shape_def: shape_defs) {

      Rect64 bounds = GetBounds(shape_def.paths);

      shape_def.item_type_id = instance_builder.add_item_type(
              bounds.Width(),
              bounds.Height(),
              -1,
              shape_def.count,
              shape_def.rotations == 0
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

          for (SolutionNodeId node_id = 0; node_id < (SolutionNodeId)solution_bin.nodes.size(); ++node_id) {

            const SolutionNode &solution_node = solution_bin.nodes[node_id];

            ItemTypeId item_type_id = solution_node.item_type_id;

            auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(),[&item_type_id](const ShapeDef &shape_def) { return shape_def.item_type_id == item_type_id; });
            if (shape_def_it != shape_defs.end()) {

              ShapeDef &shape_def = *shape_def_it;
              Rect64 bounds = GetBounds(shape_def.paths);
              bool rotated = bounds.Width() != (solution_node.r - solution_node.l);

              Shape &shape = bin.shapes.emplace_back(&shape_def);
              if (rotated) {
                shape.x = solution_node.r;
                shape.y = solution_node.b;
                shape.angle = 90;
              } else {
                shape.x = solution_node.l;
                shape.y = solution_node.b;
                shape.angle = 0;
              }

            }

            if (item_type_id >= 0 || !solution_node.children.empty()) {

              if (solution_node.d == 0) {

                if (trimming > 0) {

                  // Bottom
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.l - (first_stage_orientation == rectangleguillotine::CutOrientation::Horizontal ? trimming : 0),
                                        solution_node.b - spacing,
                                        solution_node.r + trimming,
                                        solution_node.b);

                  // Left
                  bin.cuts.emplace_back(solution_node.d,
                                        solution_node.l - spacing,
                                        solution_node.b - (first_stage_orientation == rectangleguillotine::CutOrientation::Vertical ? trimming : 0),
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

  bool IrregularEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, char *c_objective, int64_t c_spacing, int64_t c_trimming, int verbosity_level, Solution &solution, std::string &message) {

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

    for (auto &shape_def: shape_defs) {

      std::vector <irregular::ItemShape> item_shapes;

      for (auto &path: shape_def.paths) {

        irregular::ItemShape item_shape;

        for (auto point_it = begin(path); point_it != end(path); ++point_it) {

          auto point_it_next = point_it + 1;
          if (point_it_next == end(path)) {
            point_it_next = begin(path);
          }

          LengthDbl xs = (LengthDbl) (*point_it).x;
          LengthDbl ys = (LengthDbl) (*point_it).y;
          LengthDbl xe = (LengthDbl) (*point_it_next).x;
          LengthDbl ye = (LengthDbl) (*point_it_next).y;

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
              shape_def.count,
              {{0, 0}}
      );

    }

    irregular::Instance instance = instance_builder.build();

    irregular::OptimizeParameters parameters;
    parameters.optimization_mode = OptimizationMode::NotAnytimeSequential;
    parameters.not_anytime_tree_search_queue_size = 4096;
    parameters.timer.set_time_limit(60);
    parameters.verbosity_level = verbosity_level;

    const irregular::Output output = irregular::optimize(instance, parameters);
    const irregular::Solution &ps_solution = output.solution_pool.best();

    for (BinPos bin_pos = 0; bin_pos < ps_solution.number_of_different_bins(); ++bin_pos) {

      const irregular::SolutionBin &solution_bin = ps_solution.bin(bin_pos);
      BinTypeId bin_type_id = solution_bin.bin_type_id;

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) {
        return bin_def.bin_type_id == bin_type_id;
      });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(), [&item_type_id](const ShapeDef &shape_def) { return shape_def.item_type_id == item_type_id; });
            if (shape_def_it != shape_defs.end()) {

              Shape &shape = bin.shapes.emplace_back(&*shape_def_it);
              shape.x = solution_item.bl_corner.x + trimming;
              shape.y = solution_item.bl_corner.y + trimming;
              shape.angle = (int64_t) solution_item.angle;

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

  bool OneDimensionalEngine::run(ShapeDefs &shape_defs, BinDefs &bin_defs, char *c_objective, int64_t c_spacing, int64_t c_trimming, int verbosity_level, Solution &solution, std::string &message) {

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

    for (auto &shape_def: shape_defs) {

      Rect64 bounds = GetBounds(shape_def.paths);

      shape_def.item_type_id = instance_builder.add_item_type(
              bounds.Width() + spacing,
              -1,
              shape_def.count
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

      auto bin_def_it = std::find_if(bin_defs.begin(), bin_defs.end(), [&bin_type_id](const BinDef &bin_def) { return bin_def.bin_type_id == bin_type_id; });
      if (bin_def_it != bin_defs.end()) {

        for (BinPos copie = 0; copie < solution_bin.copies; ++copie) {

          Bin &bin = solution.packed_bins.emplace_back(&*bin_def_it);

          for (auto &solution_item: solution_bin.items) {

            ItemTypeId item_type_id = solution_item.item_type_id;

            auto shape_def_it = std::find_if(shape_defs.begin(), shape_defs.end(), [&item_type_id](const ShapeDef &shape_def) {  return shape_def.item_type_id == item_type_id; });
            if (shape_def_it != shape_defs.end()) {

              Shape &shape = bin.shapes.emplace_back(&*shape_def_it);
              shape.x = trimming + solution_item.start;
              shape.y = 0;
              shape.angle = 0;

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