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

#include "shape/labeling.hpp"

#include <mutex>

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

    struct ItemTypeMeta {
        ItemPos copies = 0;
    };
    using ItemTypeMetas = std::unordered_map<ItemTypeId, ItemTypeMeta>;

    struct BinTypeMeta {
        BinPos copies = 0;
    };
    using BinTypeMetas = std::unordered_map<BinTypeId, BinTypeMeta>;

    struct BinTypeStats {
        std::unordered_map<BinTypeId, ItemPos> item_copies_by_bin_type;
    };

    using Solutions = std::vector<json>;

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

        ItemTypeMeta& item_type_meta(ItemTypeId item_type_id) {
            return item_type_metas_[item_type_id];
        }

        BinTypeMeta& bin_type_meta(BinTypeId bin_type_id) {
            return bin_type_metas_[bin_type_id];
        }

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
        ) {

            if (j.contains("length_truncate_factor")) {
                length_truncate_factor_ = j.value("length_truncate_factor", 1.0);
                if (length_truncate_factor_ < 1.0) {
                    length_truncate_factor_ = 1.0;
                }
            }

        };

        virtual void read_instance(
                basic_json<>& j
        ) {

            if (j.contains("parameters")) {
                read_instance_parameters(j["parameters"]);
            }
            if (j.contains("item_types")) {
                read_item_types(j["item_types"]);
            }
            if (j.contains("bin_types")) {
                read_bin_types(j["bin_types"]);
            }

        }

        virtual void read_instance_parameters(
                basic_json<>& j
        ) {};

        virtual void read_item_types(
                basic_json<>& j
        ) {

            for (auto& j_item: j.items()) {
                auto& j_item_value = j_item.value();

                ItemTypeId item_type_id = read_item_type(j_item_value);

                // Extract useful meta to keep them for post-processing

                ItemTypeMeta item_type_meta;
                item_type_meta.copies = j_item_value.value("copies", static_cast<ItemPos>(1));
                item_type_metas_.emplace(item_type_id, item_type_meta);

            }

        }

        virtual ItemTypeId read_item_type(
                basic_json<>& j
        ) = 0;

        virtual void read_bin_types(
                basic_json<>& j
        ) {

            for (auto& j_item: j.items()) {
                auto& j_item_value = j_item.value();

                BinTypeId bin_type_id = read_bin_type(j_item_value);

                // Extract useful meta to keep them for post-processing

                BinTypeMeta bin_type_meta;
                bin_type_meta.copies = j_item_value.value("copies", static_cast<BinPos>(1));
                bin_type_metas_.emplace(bin_type_id, bin_type_meta);

            }

        }

        virtual BinTypeId read_bin_type(
                basic_json<>& j
        ) = 0;

        Length read_length(
                basic_json<>& j,
                const std::string& key,
                Length default_length = 0
        ) const {
            return to_length(j.value(key, static_cast<double>(default_length)));
        }

        /*
         * Optimize:
         */

        virtual json optimize() = 0;

    protected:

        /*
         * Utils:
         */

        Length to_length(
                const double length_dbl
        ) const {
            if (length_dbl > 0) {
                return static_cast<Length>(length_dbl * length_truncate_factor_);
            }
            return static_cast<Length>(length_dbl);
        }

        double to_length_dbl(
                const Length length,
                const int precision = 8
        ) const {
            return round(static_cast<double>(length) / length_truncate_factor_, precision);
        }

        static double to_length_dbl(
                const double length_dbl,
                const int precision = 8
        ) {
            return round(length_dbl, precision);
        }

        double to_area_dbl(
                const Area area,
                const int precision = 8
        ) const {
            return round(static_cast<double>(area) / (length_truncate_factor_ * length_truncate_factor_), precision);
        }

        static double to_area_dbl(
                const double area_dbl,
                const int precision = 8
        ) {
            return round(area_dbl, precision);
        }

        static double round(
                const double value,
                const int precision = 8
        ) {
            return std::round(value * std::pow(10, precision)) / std::pow(10, precision);
        }

    private:

        /** Parameters */
        double length_truncate_factor_ = 1.0;

        /** Type Metas */
        ItemTypeMetas item_type_metas_;
        BinTypeMetas bin_type_metas_;

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
            Solver::read_parameters(j);

            if (j.contains("time_limit")) {
                parameters_.timer.set_time_limit(j["time_limit"].get<double>());
            }
            if (j.contains("verbosity_level")) {
                parameters_.verbosity_level = j["verbosity_level"].get<int>();
            } else {
                parameters_.verbosity_level = 0;            // Override default PackingSolver value
            }
            if (j.contains("messages_to_stdout")) {
                parameters_.messages_to_stdout = j["messages_to_stdout"].get<bool>();
            } else {
                parameters_.messages_to_stdout = false;     // Override default PackingSolver value
            }
            if (j.contains("messages_to_solution")) {
                messages_to_solution_ = j["messages_to_solution"].get<bool>();
                if (messages_to_solution_) {
                    parameters_.messages_streams.push_back(&messages_stream_);
                }
            }
            if (j.contains("messages_path")) {
                parameters_.messages_path = j["messages_path"].get<std::string>();
            }
            if (j.contains("log_to_stderr")) {
                parameters_.log_to_stderr = j["log_to_stderr"].get<bool>();
            } else {
                parameters_.log_to_stderr = false;           // Override default PackingSolver value
            }
            if (j.contains("log_path")) {
                parameters_.log_path = j["log_path"].get<std::string>();
            }
            if (j.contains("instance_path")) {
                instance_path_ = j["instance_path"].get<std::string>();
            }
            if (j.contains("certificate_path")) {
                certificate_path_ = j["certificate_path"].get<std::string>();
            }

            if (j.contains("linear_programming_solver")) {
                columngenerationsolver::SolverName linear_programming_solver_name;
                std::stringstream ss(j.value("linear_programming_solver", "clp"));
                ss >> linear_programming_solver_name;
                parameters_.linear_programming_solver_name = linear_programming_solver_name;
            }
            if (j.contains("optimization_mode")) {
                OptimizationMode optimization_mode;
                std::stringstream ss(j.value("optimization_mode", "not-anytime"));
                ss >> optimization_mode;
                parameters_.optimization_mode = optimization_mode;
            }

            if (j.contains("use_tree_search")) {
                parameters_.use_tree_search = j["use_tree_search"].get<bool>();
            }
            if (j.contains("use_sequential_single_knapsack")) {
                parameters_.use_sequential_single_knapsack = j["use_sequential_single_knapsack"].get<bool>();
            }
            if (j.contains("use_sequential_value_correction")) {
                parameters_.use_sequential_value_correction = j["use_sequential_value_correction"].get<bool>();
            }
            if (j.contains("use_column_generation")) {
                parameters_.use_column_generation = j["use_column_generation"].get<bool>();
            }
            if (j.contains("use_dichotomic_search")) {
                parameters_.use_dichotomic_search = j["use_dichotomic_search"].get<bool>();
            }

            if (j.contains("not_anytime_tree_search_queue_size")) {
                parameters_.not_anytime_tree_search_queue_size = j["not_anytime_tree_search_queue_size"].get<Counter>();
            }
            if (j.contains("not_anytime_sequential_single_knapsack_subproblem_queue_size")) {
                parameters_.not_anytime_sequential_single_knapsack_subproblem_queue_size = j["not_anytime_sequential_single_knapsack_subproblem_queue_size"].get<Counter>();
            }
            if (j.contains("not_anytime_sequential_value_correction_number_of_iterations")) {
                parameters_.not_anytime_sequential_value_correction_number_of_iterations = j["not_anytime_sequential_value_correction_number_of_iterations"].get<Counter>();
            }
            if (j.contains("not_anytime_dichotomic_search_subproblem_queue_size")) {
                parameters_.not_anytime_dichotomic_search_subproblem_queue_size = j["not_anytime_dichotomic_search_subproblem_queue_size"].get<Counter>();
            }

            if (j.contains("maximum_size_of_the_solution_pool")) {
                parameters_.maximum_size_of_the_solution_pool = j["maximum_size_of_the_solution_pool"].get<Counter>();
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
        Solutions solutions_;

        /** TODO : find a better solution to prevent solution concurrency ? */
        std::mutex solutions_mutex_;

        /** Messages */
        bool messages_to_solution_ = false;
        std::stringstream messages_stream_;

        /** Instance (native PackingSolver instance write) */
        std::string instance_path_;

        /** Certificate (native PackingSolver solution write) */
        std::string certificate_path_;

        /*
         * Output
         */
        virtual void write_best_solution(
                json& j,
                const Output& output
        ) {

            const auto& solution = output.solution_pool.best();
            const auto& instance = solution.instance();

            j["time"] = output.time;

            j["full_waste"] = to_area_dbl(solution.full_waste());
            j["full_efficiency"] = 1 - solution.full_waste_percentage();
            j["cost"] = solution.cost();
            j["profit"] = solution.profit();

            j["number_of_items"] = solution.number_of_items();
            j["number_of_bins"] = solution.number_of_bins();

            BinTypeStats bin_type_stats;

            write_best_solution_bins(j, solution, bin_type_stats);

            basic_json<>& j_item_types_stats = j["item_types_stats"] = json::array();
            for (ItemTypeId item_type_id = 0; item_type_id < instance.number_of_item_types(); ++item_type_id) {

                const auto& item_type_meta = this->item_type_meta(item_type_id);
                const auto used_copies = solution.item_copies(item_type_id);
                const auto unused_copies = item_type_meta.copies < 0 ? -1 : item_type_meta.copies - used_copies;

                basic_json<> j_item_type_stats = json{
                    {"item_type_id", item_type_id}
                };

                if (used_copies > 0) j_item_type_stats["used_copies"] = used_copies;
                if (unused_copies > 0 || used_copies == 0) j_item_type_stats["unused_copies"] = unused_copies;

                populate_item_type_stats(j_item_type_stats, solution, item_type_id);

                j_item_types_stats.emplace_back(j_item_type_stats);

            }

            basic_json<>& j_bin_types_stats = j["bin_types_stats"] = json::array();
            for (BinTypeId bin_type_id = 0; bin_type_id < instance.number_of_bin_types(); ++bin_type_id) {

                const auto& bin_type_meta = this->bin_type_meta(bin_type_id);
                const auto used_copies = solution.bin_copies(bin_type_id);
                const auto unused_copies = bin_type_meta.copies < 0 ? -1 : bin_type_meta.copies - used_copies;

                basic_json<> j_bin_type_stats = json{
                    {"bin_type_id", bin_type_id},
                    {"item_copies", bin_type_stats.item_copies_by_bin_type[bin_type_id]}
                };

                if (used_copies > 0) j_bin_type_stats["used_copies"] = used_copies;
                if (unused_copies > 0 || used_copies == 0) j_bin_type_stats["unused_copies"] = unused_copies;

                populate_bin_type_stats(j_bin_type_stats, solution, bin_type_id);

                j_bin_types_stats.emplace_back(j_bin_type_stats);

            }

            if (messages_to_solution_) {
                j["messages"] = messages(); // Export PackingSolver output messages to the Packy solution
            }

            if (!certificate_path_.empty()) {
                solution.write(certificate_path_);  // Export solution to file with PackingSolver 'write' method
            }

        }

        virtual void write_best_solution_bins(
            json& j,
            const Solution& solution,
            BinTypeStats& bin_type_stats
        ) = 0;

        virtual void populate_item_type_stats(
            basic_json<>& j_item_type_stats,
            const Solution& solution,
            const ItemTypeId item_type_id
        ) {};

        virtual void populate_bin_type_stats(
            basic_json<>& j_bin_type_stats,
            const Solution& solution,
            const BinTypeId bin_type_id
        ) {};

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
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].get<NodeId>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("fake_trimming")) {
                fake_trimming_ = read_length(j, "fake_trimming", 0);
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = read_length(j, "fake_spacing", 0);
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(1));
            bool oriented = j.value("oriented", false);
            GroupId group_id = j.value("group_id", static_cast<GroupId>(0));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            ItemTypeId item_type_id = instance_builder_.add_item_type(
                    width,
                    height,
                    profit,
                    copies,
                    oriented,
                    group_id
            );

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
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

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j
        ) {

            Length x = read_length(j, "x", -1);
            Length y = read_length(j, "y", -1);
            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);

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

        /*
         * Optimize:
         */

        json optimize() override {

            const rectangle::Instance instance = instance_builder_.build();

            if (!instance_path_.empty()) {
                instance.write(instance_path_);  // Export instance to file with PackingSolver 'write' method
            }

            const rectangle::Output output = rectangle::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution_bins(
                json& j,
                const rectangle::Solution& solution,
                BinTypeStats& bin_type_stats
        ) override {

            using namespace rectangle;

            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"];
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Area bin_space = bin_type.rect.x * bin_type.rect.y;
                Area items_space = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    items_space += item_type.space();
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"space",       to_area_dbl(bin_space)},
                        {"waste",       to_area_dbl(bin_space - items_space)},
                        {"efficiency",  static_cast<double>(items_space) / bin_space}
                });

                // Add x_max and y_max attributes to the last bin
                if (bin_pos == solution.number_of_different_bins() - 1) {
                    j_bin["x_max"] = to_length_dbl(fake_trimming_ + solution.x_max() - fake_spacing_);
                    j_bin["y_max"] = to_length_dbl(fake_trimming_ + solution.y_max() - fake_spacing_);
                }

                basic_json<>& j_items = j_bin["items"] = json::array();
                for (const auto& item: bin.items) {

                    const ItemType& item_type = solution.instance().item_type(item.item_type_id);

                    if (item.rotate) {
                        j_items.emplace_back(json{
                                {"item_type_id", item.item_type_id},
                                {"x",            to_length_dbl(fake_trimming_ + item.bl_corner.x + item_type.rect.y - fake_spacing_)},
                                {"y",            to_length_dbl(fake_trimming_ + item.bl_corner.y)},
                                {"angle",        90.0}
                        });
                    } else {
                        j_items.emplace_back(json{
                                {"item_type_id", item.item_type_id},
                                {"x",            to_length_dbl(fake_trimming_ + item.bl_corner.x)},
                                {"y",            to_length_dbl(fake_trimming_ + item.bl_corner.y)},
                                {"angle",        0}
                        });
                    }

                    // Increment item copies stats
                    bin_type_stats.item_copies_by_bin_type[bin.bin_type_id] += bin.copies;

                }

                j_bin["number_of_items"] = j_items.size();

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
                instance_builder_.set_number_of_stages(j["number_of_stages"].get<Counter>());
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
                instance_builder_.set_minimum_distance_1_cuts(read_length(j, "minimum_distance_1_cuts"));
            }
            if (j.contains("maximum_distance_1_cuts")) {
                instance_builder_.set_maximum_distance_1_cuts(read_length(j, "maximum_distance_1_cuts"));
            }
            if (j.contains("minimum_distance_2_cuts")) {
                instance_builder_.set_minimum_distance_2_cuts(read_length(j, "minimum_distance_2_cuts"));
            }
            if (j.contains("minimum_waste_length")) {
                instance_builder_.set_minimum_waste_length(read_length(j, "minimum_waste_length"));
            }
            if (j.contains("maximum_number_2_cuts")) {
                instance_builder_.set_maximum_number_2_cuts(j["maximum_number_2_cuts"].get<bool>());
            }
            if (j.contains("cut_through_defects")) {
                instance_builder_.set_cut_through_defects(j["cut_through_defects"].get<bool>());
            }
            if (j.contains("cut_thickness")) {
                instance_builder_.set_cut_thickness(read_length(j, "cut_thickness"));
            }

            if (j.contains("keep_width")) {
                keep_width_ = read_length(j, "keep_width");
            }
            if (j.contains("keep_height")) {
                keep_height_ = read_length(j, "keep_height");
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(-1));
            bool oriented = j.value("oriented", false);
            StackId stack_id = j.value("stack_id", static_cast<StackId>(-1));

            ItemTypeId item_type_id = instance_builder_.add_item_type(
                    width,
                    height,
                    profit,
                    copies,
                    oriented,
                    stack_id
            );

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j
        ) override {

            using namespace rectangleguillotine;

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
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
                left_trim = read_length(j, "left_trim");
            }
            TrimType left_trim_type = TrimType::Hard;
            if (j.contains("left_trim_type")) {
                std::stringstream ss(j.value("left_trim_type", "hard"));
                ss >> left_trim_type;
            }

            Length right_trim = 0;
            if (j.contains("right_trim")) {
                right_trim = read_length(j, "right_trim");
            }
            TrimType right_trim_type = TrimType::Soft;
            if (j.contains("right_trim_type")) {
                std::stringstream ss(j.value("right_trim_type", "soft"));
                ss >> right_trim_type;
            }

            Length bottom_trim = 0;
            if (j.contains("bottom_trim")) {
                bottom_trim = read_length(j, "bottom_trim");
            }
            TrimType bottom_trim_type = TrimType::Hard;
            if (j.contains("bottom_trim_type")) {
                std::stringstream ss(j.value("bottom_trim_type", "hard"));
                ss >> bottom_trim_type;
            }

            Length top_trim = 0;
            if (j.contains("top_trim")) {
                top_trim = read_length(j, "top_trim");
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

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j
        ) {

            Length x = read_length(j, "x", -1);
            Length y = read_length(j, "y", -1);
            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);

            instance_builder_.add_defect(
                    bin_type_id,
                    x,
                    y,
                    width,
                    height
            );

        }

        /*
         * Optimize:
         */

        json optimize() override {

            const rectangleguillotine::Instance instance = instance_builder_.build();

            if (!instance_path_.empty()) {
                instance.write(instance_path_);  // Export instance to file with PackingSolver 'write' method
            }

            const rectangleguillotine::Output output = rectangleguillotine::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution_bins(
                json &j,
                const rectangleguillotine::Solution& solution,
                BinTypeStats& bin_type_stats
        ) override {

            using namespace rectangleguillotine;

            const Instance& instance = solution.instance();

            // Bins.
            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Area bin_space = bin_type.rect.area(); // Workaround to PackingSolver bin_type.space() function that subtract trims
                Area items_space = 0;
                for (const auto& node : bin.nodes) {
                    if (node.item_type_id >= 0 && node.f >= 0) {
                        const ItemType& item_type = instance.item_type(node.item_type_id);
                        items_space += item_type.rect.area();
                    }
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"space",       to_area_dbl(bin_space)},
                        {"waste",       to_area_dbl(bin_space - items_space)},
                        {"efficiency",  static_cast<double>(items_space) / bin_space}
                });

                Length cut_length = 0;
                int number_of_leftovers_to_keep = 0;

                // Items, Leftovers & Cuts.
                basic_json<>& j_items = j_bin["items"] = json::array();
                basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
                basic_json<>& j_cuts = j_bin["cuts"] = json::array();
                for (const auto& node : bin.nodes) {

                    if (node.item_type_id >= 0 && node.f >= 0) {

                        const ItemType& item_type = instance.item_type(node.item_type_id);

                        if (item_type.rect.w != node.r - node.l /* rotated */) {
                            j_items.push_back(json{
                                    {"item_type_id", node.item_type_id},
                                    {"x",            to_length_dbl(node.r)},
                                    {"y",            to_length_dbl(node.b)},
                                    {"angle",        90.0},
                            });
                        } else {
                            j_items.push_back(json{
                                    {"item_type_id", node.item_type_id},
                                    {"x",            to_length_dbl(node.l)},
                                    {"y",            to_length_dbl(node.b)},
                                    {"angle",        0.0},
                            });
                        }

                        // Increment item copies stats
                        bin_type_stats.item_copies_by_bin_type[bin.bin_type_id] += bin.copies;

                    } else if (node.d > 0 && node.children.empty()) {

                        if (node.r > node.l && node.t > node.b) {

                            const Length width = node.r - node.l;
                            const Length height = node.t - node.b;
                            bool kept = width >= keep_width_ && height >= keep_height_;

                            j_leftovers.push_back(json{
                                    {"x",      to_length_dbl(node.l)},
                                    {"y",      to_length_dbl(node.b)},
                                    {"width",  to_length_dbl(width)},
                                    {"height", to_length_dbl(height)},
                                    {"kept",   kept},
                            });

                            if (kept) {
                                number_of_leftovers_to_keep++;
                            }

                        }

                    }

                    // Extract cuts

                    if (node.d == 0) {

                        if (bin_type.left_trim + bin_type.right_trim + bin_type.bottom_trim + bin_type.top_trim > 0 && !node.children.empty()) {

                            // Bottom trim
                            if (bin_type.bottom_trim_type == TrimType::Hard) {
                                Length b_length = node.r - node.l + (bin.first_cut_orientation == CutOrientation::Horizontal ? bin_type.left_trim + (bin_type.right_trim_type == TrimType::Hard ? bin_type.right_trim : 0) : 0);
                                cut_length += b_length;

                                j_cuts.emplace_back(json{
                                        {"depth",       node.d},
                                        {"x",           to_length_dbl(node.l - (bin.first_cut_orientation == CutOrientation::Horizontal ? bin_type.left_trim : 0))},
                                        {"y",           to_length_dbl(node.b - instance.parameters().cut_thickness)},
                                        {"length",      to_length_dbl(b_length)},
                                        {"orientation", "horizontal"}
                                });
                            }

                            // Top trim
                            if (bin_type.top_trim_type == TrimType::Hard) {
                                Length t_length = node.r - node.l + (bin.first_cut_orientation == CutOrientation::Horizontal ? bin_type.left_trim + (bin_type.right_trim_type == TrimType::Hard ? bin_type.right_trim : 0) : 0);
                                cut_length += t_length;

                                j_cuts.emplace_back(json{
                                        {"depth",       node.d},
                                        {"x",           to_length_dbl(node.l - (bin.first_cut_orientation == CutOrientation::Horizontal ? bin_type.left_trim : 0))},
                                        {"y",           to_length_dbl(node.t)},
                                        {"length",      to_length_dbl(t_length)},
                                        {"orientation", "horizontal"}
                                });
                            }

                            // Left trim
                            if (bin_type.left_trim_type == TrimType::Hard) {
                                Length l_length = node.t - node.b + (bin.first_cut_orientation == CutOrientation::Vertical ? bin_type.bottom_trim + (bin_type.top_trim_type == TrimType::Hard ? bin_type.top_trim : 0) : 0);
                                cut_length += l_length;

                                j_cuts.emplace_back(json{
                                        {"depth",       node.d},
                                        {"x",           to_length_dbl(node.l - instance.parameters().cut_thickness)},
                                        {"y",           to_length_dbl(node.b - (bin.first_cut_orientation == CutOrientation::Vertical ? bin_type.bottom_trim : 0))},
                                        {"length",      to_length_dbl(l_length)},
                                        {"orientation", "vertical"},
                                });
                            }

                            // Right trim
                            if (bin_type.right_trim_type == TrimType::Hard) {
                                Length r_length = node.t - node.b + (bin.first_cut_orientation == CutOrientation::Vertical ? bin_type.bottom_trim + (bin_type.top_trim_type == TrimType::Hard ? bin_type.top_trim : 0) : 0);
                                cut_length += r_length;

                                j_cuts.emplace_back(json{
                                        {"depth",       node.d},
                                        {"x",           to_length_dbl(node.r)},
                                        {"y",           to_length_dbl(node.b - (bin.first_cut_orientation == CutOrientation::Vertical ? bin_type.bottom_trim : 0))},
                                        {"length",      to_length_dbl(r_length)},
                                        {"orientation", "vertical"},
                                });
                            }

                        }

                    } else if (node.d >= 0 && node.f >= 0) {

                        const SolutionNode& father_node = bin.nodes[node.f];

                        // Right
                        if (node.r != father_node.r) {

                            Length r_length = node.t - node.b;
                            cut_length += r_length;

                            j_cuts.emplace_back(json{
                                    {"depth",       node.d},
                                    {"x",           to_length_dbl(node.r)},
                                    {"y",           to_length_dbl(node.b)},
                                    {"length",      to_length_dbl(r_length)},
                                    {"orientation", "vertical"}
                            });

                        }

                        // Top
                        if (node.t != father_node.t) {

                            Length t_length = node.r - node.l;
                            cut_length += t_length;

                            j_cuts.emplace_back(json{
                                    {"depth",       node.d},
                                    {"x",           to_length_dbl(node.l)},
                                    {"y",           to_length_dbl(node.t)},
                                    {"length",      to_length_dbl(t_length)},
                                    {"orientation", "horizontal"},
                            });

                        }

                    }

                }

                j_bin["number_of_items"] = j_items.size();
                j_bin["number_of_leftovers"] = j_leftovers.size();
                j_bin["number_of_leftovers_to_keep"] = number_of_leftovers_to_keep;
                j_bin["number_of_cuts"] = j_cuts.size();
                j_bin["cut_length"] = to_length_dbl(cut_length);

            }

        }

    private:

        Length keep_width_ = 0;
        Length keep_height_ = 0;

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
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].get<NodeId>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("fake_trimming")) {
                fake_trimming_ = read_length(j, "fake_trimming", 0);
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = read_length(j, "fake_spacing", 0);
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j
        ) override {

            Length width = read_length(j, "width", -1);
            Profit profit = j.value("profit", static_cast<Profit>(-1));
            ItemPos copies = j.value("copies", static_cast<ItemPos>(1));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

            ItemTypeId item_type_id = instance_builder_.add_item_type(
                    width,
                    profit,
                    copies
            );

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j
        ) override {

            Length width = read_length(j, "width", -1);
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (fake_trimming_ > 0) {
                if (width >= 0) width -= fake_trimming_ * 2;
            }
            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

            BinTypeId bin_type_id = instance_builder_.add_bin_type(
                    width,
                    cost,
                    copies,
                    copies_min
            );

            return bin_type_id;
        }

        /*
         * Optimize:
         */

        json optimize() override {

            const onedimensional::Instance instance = instance_builder_.build();

            if (!instance_path_.empty()) {
                instance.write(instance_path_);  // Export instance to file with PackingSolver 'write' method
            }

            const onedimensional::Output output = onedimensional::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution_bins(
                json& j,
                const onedimensional::Solution& solution,
                BinTypeStats& bin_type_stats
        ) override {

            using namespace onedimensional;

            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                Length bin_space = bin_type.length;
                Length items_space = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    items_space += item_type.space();
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"space",       to_length_dbl(bin_space)},
                        {"waste",       to_length_dbl(bin_space - items_space)},
                        {"efficiency",  static_cast<double>(items_space) / bin_space}
                });

                // Items, Leftovers & Cuts.
                basic_json<>& j_items = j_bin["items"] = json::array();
                basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
                basic_json<>& j_cuts = j_bin["cuts"] = json::array();
                if (fake_trimming_ > 0) {
                    j_cuts.emplace_back(json{
                            {"depth", 0},
                            {"x",     to_length_dbl(fake_trimming_ - fake_spacing_)}
                    });
                }
                for (const auto& item: bin.items) {

                    const ItemType& item_type = instance.item_type(item.item_type_id);

                    // Item
                    j_items.emplace_back(json{
                            {"item_type_id", item.item_type_id},
                            {"x",            to_length_dbl(fake_trimming_ + item.start)},
                    });

                    // Increment item copies stats
                    bin_type_stats.item_copies_by_bin_type[bin.bin_type_id] += bin.copies;

                    // Cut
                    if (item.start + item_type.length < bin_type.length) {

                        j_cuts.emplace_back(json{
                                {"depth", 1},
                                {"x",     to_length_dbl(fake_trimming_ + item.start + item_type.length - fake_spacing_)}
                        });

                        // Leftover
                        if (&item == &bin.items.back()) {
                            j_leftovers.emplace_back(json{
                                    {"x",     to_length_dbl(fake_trimming_ + item.start + item_type.length)},
                                    {"width", to_length_dbl(bin_type.length - (item.start + item_type.length))},
                            });
                        }

                    }

                }

                j_bin["number_of_items"] = j_items.size();
                j_bin["number_of_leftovers"] = j_leftovers.size();
                j_bin["number_of_cuts"] = j_cuts.size();

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

            if (j.contains("initial_maximum_approximation_ratio")) {
                parameters_.initial_maximum_approximation_ratio = j["initial_maximum_approximation_ratio"].get<double>();
            }
            if (j.contains("maximum_approximation_ratio_factor")) {
                parameters_.maximum_approximation_ratio_factor = j["maximum_approximation_ratio_factor"].get<double>();
            }

            if (j.contains("sequential_value_correction_subproblem_queue_size")) {
                parameters_.sequential_value_correction_subproblem_queue_size = j["sequential_value_correction_subproblem_queue_size"].get<NodeId>();
            }
            if (j.contains("column_generation_subproblem_queue_size")) {
                parameters_.column_generation_subproblem_queue_size = j["column_generation_subproblem_queue_size"].get<NodeId>();
            }
            if (j.contains("not_anytime_maximum_approximation_ratio")) {
                parameters_.not_anytime_maximum_approximation_ratio = j["not_anytime_maximum_approximation_ratio"].get<double>();
            }

            if (j.contains("json_search_tree_path")) {
                parameters_.json_search_tree_path = j["json_search_tree_path"].get<std::string>();
            }

            // Packy specific

            if (j.contains("label_positions")) {
                label_positions_ = j["label_positions"].get<bool>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_instance_parameters(j);

            if (j.contains("item_item_minimum_spacing")) {
                instance_builder_.set_item_item_minimum_spacing(j["item_item_minimum_spacing"].get<irregular::LengthDbl>());
            }
            if (j.contains("item_bin_minimum_spacing")) {
                instance_builder_.set_item_bin_minimum_spacing(j["item_bin_minimum_spacing"].get<irregular::LengthDbl>());
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j
        ) override {

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

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j
        ) override {

            using namespace irregular;

            Shape shape = read_shape(j);
            Profit cost = j.value("cost", static_cast<Profit>(-1));
            BinPos copies = j.value("copies", static_cast<BinPos>(1));
            BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            BinTypeId bin_type_id = instance_builder_.add_bin_type(
                    shape,
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

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j
        ) {

            using namespace irregular;

            auto [shape, holes, type] = read_defect(j);

            instance_builder_.add_defect(
                    bin_type_id,
                    type,
                    shape,
                    holes
            );

        }

        /*
         * Optimize:
         */

        json optimize() override {

            const irregular::Instance instance = instance_builder_.build();

            if (!instance_path_.empty()) {
                instance.write(instance_path_);  // Export instance to file with PackingSolver 'write' method
            }

            const irregular::Output output = irregular::optimize(instance, parameters_);

            json j;
            write_best_solution(j, output);

            return std::move(j);
        }

    protected:

        void write_best_solution_bins(
                json& j,
                const irregular::Solution& solution,
                BinTypeStats& bin_type_stats
        ) override {

            using namespace irregular;

            const Instance& instance = solution.instance();

            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const SolutionBin& bin = solution.bin(bin_pos);
                const BinType& bin_type = instance.bin_type(bin.bin_type_id);

                AreaDbl bin_space = bin_type.space();
                AreaDbl items_space = 0;
                for (const auto& item : bin.items) {
                    const ItemType& item_type = instance.item_type(item.item_type_id);
                    items_space += item_type.space();
                }

                basic_json<>& j_bin = j_bins.emplace_back(json{
                        {"bin_type_id", bin.bin_type_id},
                        {"copies",      bin.copies},
                        {"space",       to_area_dbl(bin_space)},
                        {"waste",       to_area_dbl(bin_space - items_space)},
                        {"efficiency",  items_space / bin_space}
                });

                // Add x_max and y_max attributes to the last bin
                if (bin_pos == solution.number_of_different_bins() - 1) {
                    j_bin["x_max"] = to_length_dbl(solution.x_max());
                    j_bin["y_max"] = to_length_dbl(solution.y_max());
                }

                basic_json<>& j_items = j_bin["items"] = json::array();
                for (const auto& item: bin.items) {

                    j_items.emplace_back(json{
                            {"item_type_id", item.item_type_id},
                            {"x",            to_length_dbl(item.bl_corner.x)},
                            {"y",            to_length_dbl(item.bl_corner.y)},
                            {"angle",        item.angle},  // Returns angle in degrees
                            {"mirror",       item.mirror}
                    });

                    // Increment item copies stats
                    bin_type_stats.item_copies_by_bin_type[bin.bin_type_id] += bin.copies;

                }

                j_bin["number_of_items"] = j_items.size();
                j_bin["number_of_leftovers"] = 0;
                j_bin["number_of_cuts"] = 0;

            }

        }

        void populate_item_type_stats(
            basic_json<>& j_item_type_stats,
            const irregular::Solution& solution,
            const ItemTypeId item_type_id
        ) override {

            if (label_positions_) {

                auto item_type = solution.instance().item_type(item_type_id);

                irregular::ItemShape biggest_item_shape;

                if (item_type.shapes.size() > 1) {

                    // The item contains multiple item shapes.
                    // Try to find the biggest.
                    shape::AreaDbl max_area = 0;
                    for (const auto& item_shape : item_type.shapes) {

                        shape::AreaDbl area = item_shape.shape.compute_area();
                        for (const auto& hole : item_shape.holes) {
                            area -= hole.compute_area();
                        }

                        if (area > max_area) {
                            max_area = area;
                            biggest_item_shape = item_shape;
                        }

                    }

                } else {

                    // Use the first item shape
                    biggest_item_shape = item_type.shapes.front();

                }

                // Find label position
                shape::Point label_position = shape::find_label_position(biggest_item_shape.shape, biggest_item_shape.holes);

                // Write label position (relative to the shape coordinate system)
                j_item_type_stats["label_position"] = json{
                    {"x", to_length_dbl(label_position.x)},
                    {"y", to_length_dbl(label_position.y)}
                };

            }

        };

    private:

        bool label_positions_ = false;

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
                throw std::invalid_argument("Unknown shape type");
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

        static irregular::Defect read_defect(
                basic_json<>& j
        ) {

            using namespace irregular;

            Defect defect;
            defect.shape = read_shape(j);

            if (j.contains("holes")) {
                for (auto& j_item: j["holes"].items()) {
                    Shape hole = read_shape(j_item.value());
                    defect.holes.push_back(hole);
                }
            }

            defect.type = j.value("type", static_cast<DefectTypeId>(0));

            return std::move(defect);
        }

    };

}
