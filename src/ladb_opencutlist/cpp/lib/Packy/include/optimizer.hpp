#pragma once

#include "packingsolver/algorithms/common.hpp"

#include "packingsolver/rectangle/instance_builder.hpp"
#include "packingsolver/rectangle/instance.hpp"
#include "packingsolver/rectangle/optimize.hpp"

#include "packingsolver/rectangleguillotine/instance_builder.hpp"
#include "packingsolver/rectangleguillotine/instance.hpp"
#include "packingsolver/rectangleguillotine/optimize.hpp"

#include "packingsolver/onedimensional/instance_builder.hpp"
#include "packingsolver/onedimensional/instance.hpp"
#include "packingsolver/onedimensional/optimize.hpp"

#include "packingsolver/irregular/instance_builder.hpp"
#include "packingsolver/irregular/instance.hpp"
#include "packingsolver/irregular/optimize.hpp"

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

  class Optimizer {

  public:

    /** Destructor. */
    virtual ~Optimizer() = default;

    /*
     * Getters
     */

    virtual optimizationtools::Parameters& parameters() = 0;

    /*
     * Read:
     */

    virtual void read(basic_json<>& j) {

      if (j.contains("parameters")) {
        read_parameters(j["parameters"]);
      }
      if (j.contains("instance")) {
        read_instance(j["instance"]);
      }

    }

    virtual void read_parameters(basic_json<>& j) {};

    virtual void read_instance(basic_json<>& j) {

      if (j.contains("parameters")) {
        read_instance_parameters(j["parameters"]);
      }
      if (j.contains("bin_types")) {
        read_bin_types(j["bin_types"]);
      }
      if (j.contains("item_types")) {
        read_item_types(j["item_types"]);
      }

    }

    virtual void read_instance_parameters(basic_json<>& j) {};

    virtual void read_bin_types(basic_json<>& j) {

      for (auto& j_item: j.items()) {
        read_bin_type(j_item.value());
      }

    }

    virtual void read_bin_type(basic_json<>& j) {};

    virtual void read_item_types(basic_json<>& j) {

      for (auto& j_item: j.items()) {
        read_item_type(j_item.value());
      }

    }

    virtual void read_item_type(basic_json<>& j) {};

    /*
     * Optimize:
     */

    virtual json optimize() = 0;

  };

  typedef std::shared_ptr<Optimizer> OptimizerPtr;

  template<typename InstanceBuilder, typename OptimizeParameters, typename Output>
  class TypedOptimizer : public Optimizer {

  public:

    /** Constructor. */
    TypedOptimizer() = default;

    /*
     * Getters
     */

    optimizationtools::Parameters& parameters() override {
      return parameters_;
    };

    /*
     * Read:
     */

    void read_parameters(basic_json<>& j) override {

      if (j.contains("time_limit")) {
        parameters_.timer.set_time_limit(j["time_limit"].template get<double>());
      }
      if (j.contains("verbosity_level")) {
        parameters_.verbosity_level = j["verbosity_level"].template get<int>();
      }

      if (j.contains("optimization_mode")) {
        OptimizationMode optimization_mode;
        std::stringstream ss(j.value("optimization_mode", "not-anytime"));
        ss >> optimization_mode;
        parameters_.optimization_mode = optimization_mode;
      }

      if (j.contains("use_tree_search")) {
        parameters_.use_tree_search = j["use_tree_search"].template get<bool>();
      }
      if (j.contains("use_sequential_single_knapsack")) {
        parameters_.use_sequential_single_knapsack = j["use_sequential_single_knapsack"].template get<bool>();
      }
      if (j.contains("use_sequential_value_correction")) {
        parameters_.use_sequential_value_correction = j["use_sequential_value_correction"].template get<bool>();
      }
      if (j.contains("use_column_generation")) {
        parameters_.use_column_generation = j["use_column_generation"].template get<bool>();
      }
      if (j.contains("use_dichotomic_search")) {
        parameters_.use_dichotomic_search = j["use_dichotomic_search"].template get<bool>();
      }

      if (j.contains("not_anytime_tree_search_queue_size")) {
        parameters_.not_anytime_tree_search_queue_size = j["not_anytime_tree_search_queue_size"].template get<Counter>();
      }
      if (j.contains("not_anytime_sequential_single_knapsack_subproblem_queue_size")) {
        parameters_.not_anytime_sequential_single_knapsack_subproblem_queue_size = j["not_anytime_sequential_single_knapsack_subproblem_queue_size"].template get<Counter>();
      }
      if (j.contains("not_anytime_sequential_value_correction_number_of_iterations")) {
        parameters_.not_anytime_sequential_value_correction_number_of_iterations = j["not_anytime_sequential_value_correction_number_of_iterations"].template get<Counter>();
      }
      if (j.contains("not_anytime_dichotomic_search_subproblem_queue_size")) {
        parameters_.not_anytime_dichotomic_search_subproblem_queue_size = j["not_anytime_dichotomic_search_subproblem_queue_size"].template get<Counter>();
      }

    }

    void read_instance(basic_json<>& j) override {

      if (j.contains("objective")) {
        Objective objective;
        std::stringstream ss(j.value("objective", "default"));
        ss >> objective;
        instance_builder_.set_objective(objective);
      }

      Optimizer::read_instance(j);

    }

  protected:

    /** Instance builder. */
    InstanceBuilder instance_builder_;

    /** Parameters. */
    OptimizeParameters parameters_;

    /*
     * Output
     */
    virtual json to_json(const Output& output) {
      const auto& best_solution = output.solution_pool.best();
      json j = {
              {"time", output.time},
              {"number_of_bins", best_solution.number_of_bins()},
              {"number_of_different_bins", best_solution.number_of_different_bins()},
              {"cost", best_solution.cost()},
              {"number_of_items", best_solution.number_of_items()},
              {"profit", best_solution.profit()},
              {"full_waste_percentage", best_solution.full_waste_percentage()},
      };
      return std::move(j);
    }

  };

  class RectangleOptimizer : public TypedOptimizer<rectangle::InstanceBuilder, rectangle::OptimizeParameters, rectangle::Output> {

  public:

    /*
     * Read:
     */

    void read_parameters(basic_json<>& j) override {
      TypedOptimizer::read_parameters(j);

      if (j.contains("sequential_value_correction_subproblem_queue_size")) {
        parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
      }
      if (j.contains("column_generation_subproblem_queue_size")) {
        parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
      }

    }

    void read_bin_type(basic_json<>& j) override {
      TypedOptimizer::read_bin_type(j);

      Length width = j.value("width", -1);
      Length height = j.value("height", -1);
      Profit cost = j.value("cost", -1);
      BinPos copies = j.value("copies", 1);
      BinPos copies_min = j.value("copies_min", 0);

      instance_builder_.add_bin_type(
              width,
              height,
              cost,
              copies,
              copies_min
      );

    }

    void read_item_type(basic_json<>& j) override {
      TypedOptimizer::read_item_type(j);

      Length width = j.value("width", -1);
      Length height = j.value("height", -1);
      Profit profit = j.value("profit", -1);
      ItemPos copies = j.value("copies", 1);
      bool oriented = j.value("oriented", false);

      instance_builder_.add_item_type(
              width,
              height,
              profit,
              copies,
              oriented
      );

    }

    /*
     * Optimize:
     */

    json optimize() override {

      const rectangle::Instance instance = instance_builder_.build();
      const rectangle::Output output = rectangle::optimize(instance, parameters_);

      return to_json(output);
    }

  protected:

    json to_json(const rectangle::Output& output) override {
      json j = TypedOptimizer::to_json(output);

      using namespace rectangle;

      const rectangle::Solution& solution = output.solution_pool.best();

      basic_json<>& j_bins = j["bins"];
      for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

        const SolutionBin& bin = solution.bin(bin_pos);

        basic_json<>& j_bin = j_bins.emplace_back(json{
                {"bin_type_id", bin.bin_type_id},
                {"copies",      bin.copies}
        });

        basic_json<>& j_items = j_bin["items"] = json::array();
        for (const auto& item : bin.items) {

          const ItemType&  item_type = solution.instance().item_type(item.item_type_id);

          if (item.rotate) {
            j_items.emplace_back(json{
                    {"item_type_id", item.item_type_id},
                    {"x",            item.bl_corner.x + item_type.rect.y},
                    {"y",            item.bl_corner.y},
                    {"angle",        90.0}
            });
          } else {
            j_items.emplace_back(json{
                    {"item_type_id", item.item_type_id},
                    {"x",            item.bl_corner.x},
                    {"y",            item.bl_corner.y},
                    {"angle",        0}
            });
          }

        }

      }

      return j;
    }

  };

  class RectangleguillotineOptimizer : public TypedOptimizer<rectangleguillotine::InstanceBuilder, rectangleguillotine::OptimizeParameters, rectangleguillotine::Output> {

  public:

    /*
     * Read:
     */

    void read_instance_parameters(basic_json<>& j) override {

      using namespace rectangleguillotine;

      if (j.contains("number_of_stages")) {
        instance_builder_.set_number_of_stages(j["number_of_stages"].template get<Counter>());
      }
      if (j.contains("cut_type")) {
        CutType cut_type;
        std::stringstream ss(j.value("cut_type", "non-exact"));
        ss >> cut_type;
        instance_builder_.set_cut_type(cut_type);
      }
      if (j.contains("first_stage_orientation")) {
        CutOrientation first_stage_orientation;
        std::stringstream ss(j.value("first_stage_orientation", "horizontal"));
        ss >> first_stage_orientation;
        instance_builder_.set_first_stage_orientation(first_stage_orientation);
      }
      if (j.contains("min1cut")) {
        instance_builder_.set_min1cut(j["min1cut"].template get<Length>());
      }
      if (j.contains("max1cut")) {
        instance_builder_.set_max1cut(j["max1cut"].template get<Length>());
      }
      if (j.contains("min2cut")) {
        instance_builder_.set_min2cut(j["min2cut"].template get<Length>());
      }
      if (j.contains("max2cut")) {
        instance_builder_.set_max2cut(j["max2cut"].template get<Length>());
      }
      if (j.contains("cut_through_defects")) {
        instance_builder_.set_cut_through_defects(j["cut_through_defects"].template get<bool>());
      }
      if (j.contains("cut_thickness")) {
        instance_builder_.set_cut_thickness(j["cut_thickness"].template get<Length>());
      }

    }

    void read_bin_type(basic_json<>& j) override {
      TypedOptimizer::read_bin_type(j);

      using namespace rectangleguillotine;

      Length width = j.value("width", -1);
      Length height = j.value("height", -1);
      Profit cost = j.value("cost", -1);
      BinPos copies = j.value("copies", 1);
      BinPos copies_min = j.value("copies_min", 0);

      BinTypeId bin_id = instance_builder_.add_bin_type(
              width,
              height,
              cost,
              copies,
              copies_min
      );

      // Trims

      Length left_trim = 0;
      if (j.contains("left_trim")) {
        left_trim = (Length) j.value("left_trim", 0);
      }
      TrimType left_trim_type = TrimType::Hard;
      if (j.contains("left_trim_type")) {
        std::stringstream ss(j.value("left_trim_type", "hard"));
        ss >> left_trim_type;
      }

      Length right_trim = 0;
      if (j.contains("right_trim")) {
        right_trim = (Length) j.value("right_trim", 0);
      }
      TrimType right_trim_type = TrimType::Soft;
      if (j.contains("right_trim_type")) {
        std::stringstream ss(j.value("right_trim_type", "soft"));
        ss >> right_trim_type;
      }

      Length bottom_trim = 0;
      if (j.contains("bottom_trim")) {
        bottom_trim = (Length) j.value("bottom_trim", 0);
      }
      TrimType bottom_trim_type = TrimType::Hard;
      if (j.contains("bottom_trim_type")) {
        std::stringstream ss(j.value("bottom_trim_type", "hard"));
        ss >> bottom_trim_type;
      }

      Length top_trim = 0;
      if (j.contains("top_trim")) {
        top_trim = (Length) j.value("top_trim", 0);
      }
      TrimType top_trim_type = TrimType::Soft;
      if (j.contains("top_trim_type")) {
        std::stringstream ss(j.value("top_trim_type", "soft"));
        ss >> top_trim_type;
      }

      instance_builder_.add_trims(
              bin_id,
              left_trim,
              left_trim_type,
              right_trim,
              right_trim_type,
              bottom_trim,
              bottom_trim_type,
              top_trim,
              top_trim_type
      );

      // Defects

      if (j.contains("defects")) {
        for (auto& j_item: j["defects"].items()) {
          read_defect(bin_id, j_item.value());
        }
      }

    }

    void read_defect(BinTypeId bin_id, basic_json<>& j) {

      Length x = j.value("x", -1);
      Length y = j.value("y", -1);
      Length width = j.value("width", -1);
      Length height = j.value("height", -1);

      instance_builder_.add_defect(
              bin_id,
              x,
              y,
              width,
              height
      );

    }

    void read_item_type(basic_json<>& j) override {
      TypedOptimizer::read_item_type(j);

      Length width = j.value("width", -1);
      Length height = j.value("height", -1);
      Profit profit = j.value("profit", -1);
      ItemPos copies = j.value("copies", 1);
      bool oriented = j.value("oriented", false);

      instance_builder_.add_item_type(
              width,
              height,
              profit,
              copies,
              oriented
      );

    }

    /*
     * Optimize:
     */

    json optimize() override {

      const rectangleguillotine::Instance instance = instance_builder_.build();
      const rectangleguillotine::Output output = rectangleguillotine::optimize(instance, parameters_);

      return to_json(output);
    }

  protected:

    json to_json(const rectangleguillotine::Output& output) override {
      json j = TypedOptimizer::to_json(output);

      using namespace rectangleguillotine;

      const rectangleguillotine::Solution& solution = output.solution_pool.best();
      const Instance& instance = solution.instance();

      // Bins.
      basic_json<>& j_bins = j["bins"] = json::array();
      for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

        const SolutionBin& bin = solution.bin(bin_pos);
        const BinType& bin_type = instance.bin_type(bin.bin_type_id);

        basic_json<>& j_bin = j_bins.emplace_back(json {
                {"bin_type_id", bin.bin_type_id},
                {"copies",      bin.copies}
        });

        // Items & Cuts.
        basic_json<>& j_items = j_bin["items"] = json::array();
        basic_json<>& j_cuts = j_bin["cuts"] = json::array();
        for (const auto& node: bin.nodes) {

          if (node.item_type_id >= 0) {

            const ItemType &item_type = instance.item_type(node.item_type_id);
            bool rotated = item_type.rect.w != (node.r - node.l);

            if (rotated) {
              j_items.push_back(json{
                      {"item_type_id", node.item_type_id},
                      {"x",            node.r},
                      {"y",            node.b},
                      {"angle",        90.0},
              });
            } else {
              j_items.push_back(json{
                      {"item_type_id", node.item_type_id},
                      {"x",            node.l},
                      {"y",            node.b},
                      {"angle",        0.0},
              });
            }

          }

          // Extract cuts

          if (node.d == 0) {

            if (bin_type.left_trim + bin_type.right_trim + bin_type.bottom_trim + bin_type.top_trim > 0 && !node.children.empty()) {

              // Bottom
              j_cuts.emplace_back(json{
                      {"depth",       node.d},
                      {"x",           node.l - (instance.first_stage_orientation() == CutOrientation::Horizontal ? bin_type.left_trim : 0)},
                      {"y",           node.b - instance.cut_thickness()},
                      {"length",      node.r + (instance.first_stage_orientation() == CutOrientation::Horizontal ? bin_type.right_trim : 0)},
                      {"orientation", "horizontal"}
              });

              // Left
              j_cuts.emplace_back(json{
                      {"depth",       node.d},
                      {"x",           node.l - instance.cut_thickness()},
                      {"y",           node.b - (instance.first_stage_orientation() == CutOrientation::Vertical ? bin_type.bottom_trim : 0)},
                      {"length",      node.t + (instance.first_stage_orientation() == CutOrientation::Vertical ? bin_type.top_trim : 0)},
                      {"orientation", "vertical"},
              });

            }

          } else if (node.d >= 0 && node.f >= 0) {

            const SolutionNode &parent_node = bin.nodes[node.f];

            // Right
            if (node.r != parent_node.r) {
              j_cuts.emplace_back(json{
                      {"depth",       node.d},
                      {"x",           node.r},
                      {"y",           node.b},
                      {"length",      node.t + (node.d == 1 ? bin_type.top_trim : 0) - node.b},
                      {"orientation", "vertical"}
              });
            }
            // Top
            if (node.t != parent_node.t) {
              j_cuts.emplace_back(json{
                      {"depth",       node.d},
                      {"x",           node.l},
                      {"y",           node.t},
                      {"length",      node.r + (node.d == 1 ? bin_type.right_trim : 0) - node.l},
                      {"orientation", "horizontal"},
              });
            }


          }

        }

      }

      return j;
    }

  };

  class OnedimensionalOptimizer : public TypedOptimizer<onedimensional::InstanceBuilder, onedimensional::OptimizeParameters, onedimensional::Output> {

  public:

    /*
     * Read:
     */

    void read_parameters(basic_json<>& j) override {
      TypedOptimizer::read_parameters(j);

      if (j.contains("sequential_value_correction_subproblem_queue_size")) {
        parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
      }
      if (j.contains("column_generation_subproblem_queue_size")) {
        parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
      }

    }

    void read_bin_type(basic_json<>& j) override {
      TypedOptimizer::read_bin_type(j);

      Length width = j.value("width", -1);
      Profit cost = j.value("cost", -1);
      BinPos copies = j.value("copies", 1);
      BinPos copies_min = j.value("copies_min", 0);

      instance_builder_.add_bin_type(
              width,
              cost,
              copies,
              copies_min
      );

    }

    void read_item_type(basic_json<>& j) override {
      TypedOptimizer::read_item_type(j);

      Length width = j.value("width", -1);
      Profit profit = j.value("profit", -1);
      ItemPos copies = j.value("copies", 1);

      instance_builder_.add_item_type(
              width,
              profit,
              copies
      );

    }

    /*
     * Optimize:
     */

    json optimize() override {

      const onedimensional::Instance instance = instance_builder_.build();
      const onedimensional::Output output = onedimensional::optimize(instance, parameters_);

      return to_json(output);
    }

  protected:

    json to_json(const onedimensional::Output& output) override {
      json j = TypedOptimizer::to_json(output);

      using namespace onedimensional;

      const onedimensional::Solution& solution = output.solution_pool.best();

       basic_json<>& j_bins = j["bins"] = json::array();
      for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

        const SolutionBin& bin = solution.bin(bin_pos);
        const Instance& instance = solution.instance();
        const BinType &bin_type = instance.bin_type(bin.bin_type_id);

        basic_json<>& j_bin = j_bins.emplace_back(json{
                {"bin_type_id", bin.bin_type_id},
                {"copies",      bin.copies}
        });

        basic_json<>& j_items = j_bin["items"] = json::array();
        basic_json<>& j_cuts = j_bin["cuts"] = json::array();
        for (const auto& item : bin.items) {

          const ItemType &item_type = instance.item_type(item.item_type_id);

          // Item
          j_items.emplace_back(json{
                  {"item_type_id", item.item_type_id},
                  {"x",            item.start},
          });

          // Cut
          if (item.start + item_type.length < bin_type.length) {
            j_cuts.emplace_back(json{
                    {"depth", 1},
                    {"x",     item.start + item_type.length}
            });
          }

        }

      }

      return j;
    }

  };

  class IrregularOptimizer : public TypedOptimizer<irregular::InstanceBuilder, irregular::OptimizeParameters, irregular::Output> {

  public:

    /*
     * Read:
     */

    void read_parameters(basic_json<>& j) override {
      TypedOptimizer::read_parameters(j);

      if (j.contains("sequential_value_correction_subproblem_queue_size")) {
        parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
      }
      if (j.contains("column_generation_subproblem_queue_size")) {
        parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
      }

    }

    void read_instance_parameters(basic_json<>& j) override {
      TypedOptimizer::read_instance_parameters(j);

      if (j.contains("item_item_minimum_spacing")) {
        instance_builder_.set_item_item_minimum_spacing(j["item_item_minimum_spacing"].template get<irregular::LengthDbl>());
      }
      if (j.contains("item_bin_minimum_spacing")) {
        instance_builder_.set_item_bin_minimum_spacing(j["item_bin_minimum_spacing"].template get<irregular::LengthDbl>());
      }

    }

    void read_bin_type(basic_json<>& j) override {
      TypedOptimizer::read_bin_type(j);

      using namespace irregular;

      Shape shape = read_shape(j);
      Profit cost = j.value("cost", -1);
      BinPos copies = j.value("copies", 1);
      BinPos copies_min = j.value("copies_min", 0);

      instance_builder_.add_bin_type(
              shape,
              cost,
              copies,
              copies_min
      );

    }

    void read_item_type(basic_json<>& j) override {
      TypedOptimizer::read_item_type(j);

      using namespace irregular;

      std::vector<ItemShape> item_shapes;
      if (j.contains("shapes")) {

        // Multiple item shape.
        for (auto& j_item: j["shapes"].items()) {
          item_shapes.push_back(read_item_shape(j_item.value()));
        }

      } else {

        // Single item shape.
        item_shapes.push_back(read_item_shape(j));

      }

      Profit profit = j.value("profit", -1);
      ItemPos copies = j.value("copies", 1);

      // Read allowed rotations. (Angles are read in degrees)
      std::vector<std::pair<Angle, Angle>> allowed_rotations;
      if (j.contains("allowed_rotations")) {
        for (auto& j_item: j["allowed_rotations"].items()) {
          auto& j_angles = j_item.value();
          Angle angle_start = j_angles.value("start", 0.0);
          Angle angle_end = j_angles.value("end", angle_start);
          allowed_rotations.emplace_back(angle_start, angle_end);
        }
      }

      ItemTypeId item_type_id = instance_builder_.add_item_type(
              item_shapes,
              profit,
              copies,
              allowed_rotations
      );

      bool allow_mirroring = j.value("allow_mirroring", false);
      instance_builder_.set_item_type_allow_mirroring(item_type_id, allow_mirroring);

    }

    /*
     * Optimize:
     */

    json optimize() override {

      const irregular::Instance instance = instance_builder_.build();
      const irregular::Output output = irregular::optimize(instance, parameters_);

      return to_json(output);
    }

  protected:

    json to_json(const irregular::Output& output) override {
      json j = TypedOptimizer::to_json(output);

      using namespace irregular;

      const irregular::Solution& solution = output.solution_pool.best();

      basic_json<>& j_bins = j["bins"] = json::array();
      for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

        const SolutionBin& bin = solution.bin(bin_pos);

        basic_json<>& j_bin = j_bins.emplace_back(json{
                {"bin_type_id", bin.bin_type_id},
                {"copies",      bin.copies},
        });

        basic_json<>& j_items = j_bin["items"] = json::array();
        for (const auto& item : bin.items) {

          j_items.emplace_back(json{
                  {"item_type_id", item.item_type_id},
                  {"x",            item.bl_corner.x},
                  {"y",            item.bl_corner.y},
                  {"angle",        item.angle},  // Returns angle in degrees
                  {"mirror",       item.mirror}
          });

        }

      }

      return j;
    }

  private:

    static irregular::Shape read_shape(basic_json<>& j) {

      using namespace irregular;

      Shape shape;
      if (j["type"] == "circle") {

        LengthDbl radius = j.value("radius", -1.0);

        ShapeElement element;
        element.type = ShapeElementType::CircularArc;
        element.center = {0.0, 0.0};
        element.start = {radius, 0.0};
        element.end = element.start;
        shape.elements.push_back(element);

      } else if (j["type"] == "rectangle") {

        LengthDbl width = j.value("width", -1.0);
        LengthDbl height = j.value("height", -1.0);

        ShapeElement element_1;
        ShapeElement element_2;
        ShapeElement element_3;
        ShapeElement element_4;
        element_1.type = ShapeElementType::LineSegment;
        element_2.type = ShapeElementType::LineSegment;
        element_3.type = ShapeElementType::LineSegment;
        element_4.type = ShapeElementType::LineSegment;
        element_1.start = {0.0, 0.0};
        element_1.end = {width, 0.0};
        element_2.start = {width, 0.0};
        element_2.end = {width, height};
        element_3.start = {width, height};
        element_3.end = {0.0, height};
        element_4.start = {0.0, height};
        element_4.end = {0.0, 0.0};
        shape.elements.push_back(element_1);
        shape.elements.push_back(element_2);
        shape.elements.push_back(element_3);
        shape.elements.push_back(element_4);

      } else if (j["type"] == "polygon") {

        for (auto it = j["vertices"].begin(); it != j["vertices"].end(); ++it) {
          auto it_next = it + 1;
          if (it_next == j["vertices"].end()) {
            it_next = j["vertices"].begin();
          }
          ShapeElement element;
          element.type = ShapeElementType::LineSegment;
          element.start = {(*it)["x"], (*it)["y"]};
          element.end = {(*it_next)["x"], (*it_next)["y"]};
          shape.elements.push_back(element);
        }

      } else if (j["type"] == "general") {

        for (auto it = j["elements"].begin(); it != j["elements"].end(); ++it) {
          auto json_element = *it;
          ShapeElement element;
          element.type = str2element(json_element["type"]);
          element.start.x = json_element["start"]["x"];
          element.start.y = json_element["start"]["y"];
          element.end.x = json_element["end"]["x"];
          element.end.y = json_element["end"]["y"];
          if (element.type == ShapeElementType::CircularArc) {
            element.center.x = json_element["center"]["x"];
            element.center.y = json_element["center"]["y"];
            element.anticlockwise = json_element["anticlockwise"];
          }
          shape.elements.push_back(element);
        }

      } else {
        throw std::invalid_argument("Unknow shape type");
      }

      return std::move(shape);
    }

    static irregular::ItemShape read_item_shape(basic_json<>& j) {

      using namespace irregular;

      ItemShape item_shape;
      item_shape.shape = read_shape(j);

      if (j.contains("holes")) {
        for (auto& j_item: j["holes"].items()) {
          Shape hole = read_shape(j_item.value());
          item_shape.holes.push_back(hole);
        }
      }

      return std::move(item_shape);
    }

  };

}
