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

#include <mutex>

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

    class Solver {

    public:

        /** Destructor. */
        virtual ~Solver() = default;

        /*
         * Getters
         */

        virtual optimizationtools::Parameters& parameters() = 0;

        virtual size_t solutions_size() = 0;
        virtual json solutions_back() = 0;

        virtual bool messages_to_solution() = 0;
        virtual std::string messages() = 0;

        /*
         * Read:
         */

        virtual void read(
                basic_json<>& j
        ) {

            if (j.contains("parameters")) {
                read_parameters(j["parameters"]);
            }
            if (j.contains("instance")) {
                read_instance(j["instance"]);
            }

        }

        virtual void read_parameters(
                basic_json<>& j
        ) {};

        virtual void read_instance(
                basic_json<>& j
        ) {

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

        virtual void read_instance_parameters(
                basic_json<>& j
        ) {};

        virtual void read_bin_types(
                basic_json<>& j
        ) {

            for (auto& j_item: j.items()) {
                read_bin_type(j_item.value());
            }

        }

        virtual void read_bin_type(
                basic_json<>& j
        ) {};

        virtual void read_item_types(
                basic_json<>& j
        ) {

            for (auto& j_item: j.items()) {
                read_item_type(j_item.value());
            }

        }

        virtual void read_item_type(
                basic_json<>& j
        ) {};

        /*
         * Optimize:
         */

        virtual json optimize() = 0;

    };

    typedef std::shared_ptr<Solver> SolverPtr;

    template<typename InstanceBuilder, typename Instance, typename OptimizeParameters, typename Output, typename Solution>
    class TypedSolver : public Solver {

    public:

        /** Constructor. */
        TypedSolver() = default;

        /*
         * Getters
         */

        optimizationtools::Parameters& parameters() override {
            return parameters_;
        };

        size_t solutions_size() override {
            std::lock_guard<std::mutex> lock(solutions_mutex_);
            return solutions_.size();
        };

        json solutions_back() override {
            std::lock_guard<std::mutex> lock(solutions_mutex_);
            return std::move(solutions_.back());
        };

        bool messages_to_solution() override {
            return messages_to_solution_;
        }

        std::string messages() override {
            return messages_stream_.str();
        }

        /*
         * Read:
         */

        void read_parameters(
                basic_json<>& j
        ) override {

            if (j.contains("time_limit")) {
                parameters_.timer.set_time_limit(j["time_limit"].template get<double>());
            }
            if (j.contains("verbosity_level")) {
                parameters_.verbosity_level = j["verbosity_level"].template get<int>();
            } else {
                parameters_.verbosity_level = 0;            // Override default PackingSolver value
            }
            if (j.contains("messages_to_stdout")) {
                parameters_.messages_to_stdout = j["messages_to_stdout"].template get<bool>();
            } else {
                parameters_.messages_to_stdout = false;     // Override default PackingSolver value
            }
            if (j.contains("messages_to_solution")) {
                messages_to_solution_ = j["messages_to_solution"].template get<bool>();
                if (messages_to_solution_) {
                    parameters_.messages_streams.push_back(&messages_stream_);
                }
            }
            if (j.contains("messages_path")) {
                parameters_.messages_path = j["messages_path"].template get<std::string>();
            }
            if (j.contains("log_to_stderr")) {
                parameters_.log_to_stderr = j["log_to_stderr"].template get<bool>();
            } else {
                parameters_.log_to_stderr = false;           // Override default PackingSolver value
            }
            if (j.contains("log_path")) {
                parameters_.log_path = j["log_path"].template get<std::string>();
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

            if (j.contains("maximum_size_of_the_solution_pool")) {
                parameters_.maximum_size_of_the_solution_pool = j["maximum_size_of_the_solution_pool"].template get<Counter>();
            }

            parameters_.new_solution_callback = [&](
                    const packingsolver::Output<Instance, Solution>& output
            ) {
                std::lock_guard<std::mutex> lock(solutions_mutex_);
                json j_solution;
                write_best_solution(j_solution, dynamic_cast<const Output&>(output));
                solutions_.push_back(j_solution);
            };

        }

        void read_instance(
                basic_json<>& j
        ) override {

            if (j.contains("objective")) {
                Objective objective;
                std::stringstream ss(j.value("objective", "default"));
                ss >> objective;
                instance_builder_.set_objective(objective);
            }

            Solver::read_instance(j);

        }

    protected:

        /** Instance builder. */
        InstanceBuilder instance_builder_;

        /** Parameters. */
        OptimizeParameters parameters_;

        /** Solutions. */
        std::vector<json> solutions_;

        /** TODO : find a better solution to prevent solution concurrency ? */
        std::mutex solutions_mutex_;

        /** Messages */
        bool messages_to_solution_ = false;
        std::stringstream messages_stream_;

        /*
         * Output
         */
        virtual void write_best_solution(
                json& j,
                const Output& output
        ) {

            const auto& solution = output.solution_pool.best();

            j["time"] = output.time;
            j["number_of_bins"] = solution.number_of_bins();
            j["number_of_different_bins"] = solution.number_of_different_bins();
            j["cost"] = solution.cost();
            j["number_of_items"] = solution.number_of_items();
            j["profit"] = solution.profit();
            j["efficiency"] = 1 - solution.full_waste_percentage();

            if (messages_to_solution_) {
                j["messages"] = messages();
            }

        }

    };

    class RectangleSolver : public TypedSolver<rectangle::InstanceBuilder, rectangle::Instance, rectangle::OptimizeParameters, rectangle::Output, rectangle::Solution> {

    public:

        /*
         * Read:
         */

        void read_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_parameters(j);

            if (j.contains("sequential_value_correction_subproblem_queue_size")) {
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("fake_trimming")) {
                fake_trimming_ = j["fake_trimming"].template get<Length>();
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = j["fake_spacing"].template get<Length>();
            }

        }

        void read_bin_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_bin_type(j);

            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (fake_trimming_ > 0) {
                if (width >= 0) width -= fake_trimming_ * 2;
                if (height >= 0) height -= fake_trimming_ * 2;
            }
            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            BinTypeId bin_type_id = instance_builder_.add_bin_type(
                    width,
                    height,
                    cost,
                    copies,
                    copies_min
            );

            // Defects

            if (j.contains("defects")) {
                for (auto& j_item: j["defects"].items()) {
                    read_defect(bin_type_id, j_item.value());
                }
            }

        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j
        ) {

            Length x = j.value("x", static_cast<Length>(-1));
            Length y = j.value("y", static_cast<Length>(-1));
            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));

            if (fake_spacing_ > 0) {
                if (x >= 0) x -= fake_spacing_ / 2;
                if (y >= 0) y -= fake_spacing_ / 2;
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            instance_builder_.add_defect(
                    bin_type_id,
                    x,
                    y,
                    width,
                    height
            );

        }

        void read_item_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_item_type(j);

            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(1));
            bool oriented = j.value("oriented", false);
            GroupId group_id = j.value("group_id", static_cast<GroupId>(-1));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            instance_builder_.add_item_type(
                    width,
                    height,
                    profit,
                    copies,
                    oriented,
                    group_id
            );

        }

        /*
         * Optimize:
         */

        json optimize() override {

            const rectangle::Instance instance = instance_builder_.build();
            const rectangle::Output output = rectangle::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution(
                json& j,
                const rectangle::Output& output
        ) override {
            TypedSolver::write_best_solution(j, output);

            using namespace rectangle;

            const Solution& solution = output.solution_pool.best();
            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"];
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Area item_area = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    item_area += item_type.area();
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"efficiency",  (double) item_area / bin_type.area()}
                });

                basic_json<>& j_items = j_bin["items"] = json::array();
                for (const auto& item: bin.items) {

                    const ItemType& item_type = solution.instance().item_type(item.item_type_id);

                    if (item.rotate) {
                        j_items.emplace_back(json{
                                {"item_type_id", item.item_type_id},
                                {"x",            fake_trimming_ + item.bl_corner.x + item_type.rect.y - fake_spacing_},
                                {"y",            fake_trimming_ + item.bl_corner.y},
                                {"angle",        90.0}
                        });
                    } else {
                        j_items.emplace_back(json{
                                {"item_type_id", item.item_type_id},
                                {"x",            fake_trimming_ + item.bl_corner.x},
                                {"y",            fake_trimming_ + item.bl_corner.y},
                                {"angle",        0}
                        });
                    }

                }

            }

        }

    private:

        Length fake_trimming_ = 0;
        Length fake_spacing_ = 0;

    };

    class RectangleguillotineSolver : public TypedSolver<rectangleguillotine::InstanceBuilder, rectangleguillotine::Instance, rectangleguillotine::OptimizeParameters, rectangleguillotine::Output, rectangleguillotine::Solution> {

    public:

        /*
         * Read:
         */

        void read_instance_parameters(
                basic_json<>& j
        ) override {

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
            if (j.contains("minimum_distance_1_cuts")) {
                instance_builder_.set_minimum_distance_1_cuts(j["minimum_distance_1_cuts"].template get<Length>());
            }
            if (j.contains("maximum_distance_1_cuts")) {
                instance_builder_.set_maximum_distance_1_cuts(j["maximum_distance_1_cuts"].template get<Length>());
            }
            if (j.contains("minimum_distance_2_cuts")) {
                instance_builder_.set_minimum_distance_2_cuts(j["minimum_distance_2_cuts"].template get<Length>());
            }
            if (j.contains("minimum_waste_length")) {
                instance_builder_.set_minimum_waste_length(j["minimum_waste_length"].template get<Length>());
            }
            if (j.contains("cut_through_defects")) {
                instance_builder_.set_cut_through_defects(j["cut_through_defects"].template get<bool>());
            }
            if (j.contains("cut_thickness")) {
                instance_builder_.set_cut_thickness(j["cut_thickness"].template get<Length>());
            }

        }

        void read_bin_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_bin_type(j);

            using namespace rectangleguillotine;

            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            BinTypeId bin_type_id = instance_builder_.add_bin_type(
                    width,
                    height,
                    cost,
                    copies,
                    copies_min
            );

            // Trims

            Length left_trim = 0;
            if (j.contains("left_trim")) {
                left_trim = j.value("left_trim", static_cast<Length>(0));
            }
            TrimType left_trim_type = TrimType::Hard;
            if (j.contains("left_trim_type")) {
                std::stringstream ss(j.value("left_trim_type", "hard"));
                ss >> left_trim_type;
            }

            Length right_trim = 0;
            if (j.contains("right_trim")) {
                right_trim = j.value("right_trim", static_cast<Length>(0));
            }
            TrimType right_trim_type = TrimType::Soft;
            if (j.contains("right_trim_type")) {
                std::stringstream ss(j.value("right_trim_type", "soft"));
                ss >> right_trim_type;
            }

            Length bottom_trim = 0;
            if (j.contains("bottom_trim")) {
                bottom_trim = j.value("bottom_trim", static_cast<Length>(0));
            }
            TrimType bottom_trim_type = TrimType::Hard;
            if (j.contains("bottom_trim_type")) {
                std::stringstream ss(j.value("bottom_trim_type", "hard"));
                ss >> bottom_trim_type;
            }

            Length top_trim = 0;
            if (j.contains("top_trim")) {
                top_trim = j.value("top_trim", static_cast<Length>(0));
            }
            TrimType top_trim_type = TrimType::Soft;
            if (j.contains("top_trim_type")) {
                std::stringstream ss(j.value("top_trim_type", "soft"));
                ss >> top_trim_type;
            }

            instance_builder_.add_trims(
                    bin_type_id,
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
                    read_defect(bin_type_id, j_item.value());
                }
            }

        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j
        ) {

            Length x = j.value("x", static_cast<Length>(-1));
            Length y = j.value("y", static_cast<Length>(-1));
            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));

            instance_builder_.add_defect(
                    bin_type_id,
                    x,
                    y,
                    width,
                    height
            );

        }

        void read_item_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_item_type(j);

            Length width = j.value("width", static_cast<Length>(-1));
            Length height = j.value("height", static_cast<Length>(-1));
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(-1));
            bool oriented = j.value("oriented", false);
            StackId stack_id = j.value("stack_id", static_cast<StackId>(-1));

            instance_builder_.add_item_type(
                    width,
                    height,
                    profit,
                    copies,
                    oriented,
                    stack_id
            );

        }

        /*
         * Optimize:
         */

        json optimize() override {

            const rectangleguillotine::Instance instance = instance_builder_.build();
            const rectangleguillotine::Output output = rectangleguillotine::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution(
                json &j,
                const rectangleguillotine::Output& output
        ) override {
            TypedSolver::write_best_solution(j, output);

            using namespace rectangleguillotine;

            const Solution& solution = output.solution_pool.best();
            const Instance& instance = solution.instance();

            // Bins.
            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Area item_area = 0;
                for (const auto& node : bin.nodes) {
                    if (node.item_type_id >= 0) {
                        const ItemType& item_type = instance.item_type(node.item_type_id);
                        item_area += item_type.area();
                    }
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"efficiency",  (double) item_area / bin_type.area()}
                });

                // Items, Leftovers & Cuts.
                basic_json<>& j_items = j_bin["items"] = json::array();
                basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
                basic_json<>& j_cuts = j_bin["cuts"] = json::array();
                for (const auto& node: bin.nodes) {

                    if (node.item_type_id >= 0) {

                        const ItemType& item_type = instance.item_type(node.item_type_id);
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

                    } else if (node.d > 0 && node.children.empty()) {

                        Length l = node.l;
                        Length b = node.b;
                        if (node.f >= 0) {

                            const SolutionNode& parent_node = bin.nodes[node.f];

                            if (node.l != parent_node.l) {
                                l += instance.parameters().cut_thickness;
                            }
                            if (node.b != parent_node.b) {
                                b += instance.parameters().cut_thickness;
                            }

                        }

                        Length width = node.r - l;
                        Length height = node.t - b;
                        if (width > 0 && height > 0) {
                            j_leftovers.push_back(json{
                                    {"x",      l},
                                    {"y",      b},
                                    {"width",  width},
                                    {"height", height}
                            });
                        }

                    }

                    // Extract cuts

                    if (node.d == 0) {

                        if (bin_type.left_trim + bin_type.right_trim + bin_type.bottom_trim + bin_type.top_trim > 0 && !node.children.empty()) {

                            // Bottom
                            j_cuts.emplace_back(json{
                                    {"depth",       node.d},
                                    {"x",           node.l - (instance.parameters().first_stage_orientation == CutOrientation::Horizontal ? bin_type.left_trim : 0)},
                                    {"y",           node.b - instance.parameters().cut_thickness},
                                    {"length",      node.r + (instance.parameters().first_stage_orientation == CutOrientation::Horizontal ? bin_type.right_trim : 0)},
                                    {"orientation", "horizontal"}
                            });

                            // Left
                            j_cuts.emplace_back(json{
                                    {"depth",       node.d},
                                    {"x",           node.l - instance.parameters().cut_thickness},
                                    {"y",           node.b - (instance.parameters().first_stage_orientation == CutOrientation::Vertical ? bin_type.bottom_trim : 0)},
                                    {"length",      node.t + (instance.parameters().first_stage_orientation == CutOrientation::Vertical ? bin_type.top_trim : 0)},
                                    {"orientation", "vertical"},
                            });

                        }

                    } else if (node.d >= 0 && node.f >= 0) {

                        const SolutionNode& parent_node = bin.nodes[node.f];

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

        }

    };

    class OnedimensionalSolver : public TypedSolver<onedimensional::InstanceBuilder, onedimensional::Instance, onedimensional::OptimizeParameters, onedimensional::Output, onedimensional::Solution> {

    public:

        /*
         * Read:
         */

        void read_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_parameters(j);

            if (j.contains("sequential_value_correction_subproblem_queue_size")) {
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("fake_trimming")) {
                fake_trimming_ = j["fake_trimming"].template get<Length>();
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = j["fake_spacing"].template get<Length>();
            }

        }

        void read_bin_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_bin_type(j);

            Length width = j.value("width", static_cast<Length>(-1));
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (fake_trimming_ > 0) {
                if (width >= 0) width -= fake_trimming_ * 2;
            }
            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

            instance_builder_.add_bin_type(
                    width,
                    cost,
                    copies,
                    copies_min
            );

        }

        void read_item_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_item_type(j);

            Length width = j.value("width", static_cast<Length>(-1));
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(1));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

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

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution(
                json& j,
                const onedimensional::Output& output
        ) override {
            TypedSolver::write_best_solution(j, output);

            using namespace onedimensional;

            const Solution& solution = output.solution_pool.best();
            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Length item_length = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    item_length += item_type.length;
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"efficiency",  (double) item_length / bin_type.length}
                });

                basic_json<>& j_items = j_bin["items"] = json::array();
                basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
                basic_json<>& j_cuts = j_bin["cuts"] = json::array();
                if (fake_trimming_ > 0) {
                    j_cuts.emplace_back(json{
                            {"depth", 0},
                            {"x",     fake_trimming_ - fake_spacing_}
                    });
                }
                for (const auto& item: bin.items) {

                    const ItemType& item_type = instance.item_type(item.item_type_id);

                    // Item
                    j_items.emplace_back(json{
                            {"item_type_id", item.item_type_id},
                            {"x",            fake_trimming_ + item.start},
                    });

                    // Cut
                    if (item.start + item_type.length < bin_type.length) {
                        j_cuts.emplace_back(json{
                                {"depth", 1},
                                {"x",     fake_trimming_ + item.start + item_type.length - fake_spacing_}
                        });

                        // Leftover
                        if (&item == &bin.items.back()) {
                            j_leftovers.emplace_back(json{
                                    {"x",     fake_trimming_ + item.start + item_type.length},
                                    {"width", bin_type.length - (item.start + item_type.length)},
                            });
                        }

                    }

                }

            }

        }

    private:

        Length fake_trimming_ = 0;
        Length fake_spacing_ = 0;

    };

    class IrregularSolver : public TypedSolver<irregular::InstanceBuilder, irregular::Instance, irregular::OptimizeParameters, irregular::Output, irregular::Solution> {

    public:

        /*
         * Read:
         */

        void read_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_parameters(j);

            if (j.contains("sequential_value_correction_subproblem_queue_size")) {
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].template get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].template get<NodeId>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("item_item_minimum_spacing")) {
                instance_builder_.set_item_item_minimum_spacing(j["item_item_minimum_spacing"].template get<irregular::LengthDbl>());
            }
            if (j.contains("item_bin_minimum_spacing")) {
                instance_builder_.set_item_bin_minimum_spacing(j["item_bin_minimum_spacing"].template get<irregular::LengthDbl>());
            }

        }

        void read_bin_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_bin_type(j);

            using namespace irregular;

            Shape shape = read_shape(j);
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            instance_builder_.add_bin_type(
                    shape,
                    cost,
                    copies,
                    copies_min
            );

        }

        void read_item_type(
                basic_json<>& j
        ) override {
            TypedSolver::read_item_type(j);

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

            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(1));

            // Read allowed rotations. (Angles are read in degrees)
            std::vector<std::pair<Angle, Angle>> allowed_rotations;
            if (j.contains("allowed_rotations")) {
                for (auto& j_item: j["allowed_rotations"].items()) {
                    auto& j_angles = j_item.value();
                    Angle angle_start = j_angles.value("start", static_cast<Angle>(0));
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

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution(
                json& j,
                const irregular::Output& output
        ) override {
            TypedSolver::write_best_solution(j, output);

            using namespace irregular;

            const Solution& solution = output.solution_pool.best();
            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                AreaDbl item_area = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    item_area += item_type.area;
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"efficiency",  item_area / bin_type.area}
                });

                basic_json<>& j_items = j_bin["items"] = json::array();
                for (const auto& item: bin.items) {

                    j_items.emplace_back(json{
                            {"item_type_id", item.item_type_id},
                            {"x",            item.bl_corner.x},
                            {"y",            item.bl_corner.y},
                            {"angle",        item.angle},  // Returns angle in degrees
                            {"mirror",       item.mirror}
                    });

                }

            }

        }

    private:

        static irregular::Shape read_shape(
                basic_json<>& j
        ) {

            using namespace irregular;

            Shape shape;
            if (j["type"] == "circle") {

                LengthDbl radius = j.value("radius", static_cast<LengthDbl>(-1));

                ShapeElement element;
                element.type = ShapeElementType::CircularArc;
                element.center = {0.0, 0.0};
                element.start = {radius, 0.0};
                element.end = element.start;
                shape.elements.push_back(element);

            } else if (j["type"] == "rectangle") {

                LengthDbl width = j.value("width", static_cast<LengthDbl>(-1));
                LengthDbl height = j.value("height", static_cast<LengthDbl>(-1));

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

        static irregular::ItemShape read_item_shape(
                basic_json<>& j
        ) {

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
