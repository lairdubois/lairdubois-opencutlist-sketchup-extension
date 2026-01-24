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
#include <shape/clean.hpp>

#include <mutex>

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

    struct ItemTypeMeta {
        ItemTypeId orig_item_type_id = -1;
        ItemTypeId usable_item_type_id = -1;
        ItemPos copies = 0;
        bool usable = true;
    };
    using ItemTypeMetas = std::unordered_map<ItemTypeId, ItemTypeMeta>;

    struct BinTypeMeta {
        BinPos copies = 0;
        double width_dbl = 0;
        double height_dbl = 0;
    };
    using BinTypeMetas = std::unordered_map<BinTypeId, BinTypeMeta>;

    struct BinTypeStats {
        std::unordered_map<BinTypeId, ItemPos> item_copies_by_bin_type;
    };

    using Solutions = std::vector<json>;

    class Solver {

    public:

        /** Constructor. */
        Solver() = default;

        /** Destructor. */
        virtual ~Solver() = default;

        /*
         * End
         */

        virtual void add_end_boolean(
            const bool* end
        ) = 0;

        /*
         * Getters
         */

        virtual size_t solutions_size() = 0;
        virtual json solutions_back() = 0;

        /*
         * Read:
         */

        virtual void read(
            basic_json<>& j
        ) = 0;

        /*
         * Optimize:
         */

        virtual json optimize() = 0;

    };

    typedef std::shared_ptr<Solver> SolverPtr;

    template<typename InstanceBuilder>
    class TypedBuilder {
    public:

        /*
         * Getters:
         */

        bool used() {
            return used_;
        }

        InstanceBuilder& instance_builder() {
            return instance_builder_;
        };

        ItemTypeMetas& item_type_metas() {
            return item_type_metas_;
        }

        ItemTypeMeta& item_type_meta(ItemTypeId item_type_id) {
            return item_type_metas_[item_type_id];
        }

        BinTypeMetas& bin_type_metas() {
            return bin_type_metas_;
        }

        BinTypeMeta& bin_type_meta(BinTypeId bin_type_id) {
            return bin_type_metas_[bin_type_id];
        }

        /*
         * Setters:
         */

        void set_used(bool used) {
            used_ = used;
        }

        void set_item_type_meta(
            const ItemTypeId item_type_id,
            const ItemTypeMeta& item_type_meta
        ) {
            item_type_metas_.emplace(item_type_id, item_type_meta);
        }

        void set_bin_type_meta(
            const BinTypeId bin_type_id,
            const BinTypeMeta& bin_type_meta
        ) {
            bin_type_metas_.emplace(bin_type_id, bin_type_meta);
        }

    protected:

        /** Status. */
        bool used_ = false;

        /** Instance builder. */
        InstanceBuilder instance_builder_;

        /** Type Metas. */
        ItemTypeMetas item_type_metas_;
        BinTypeMetas bin_type_metas_;

    };

    template<typename InstanceBuilder, typename Instance, typename ItemType, typename BinType, typename OptimizeParameters, typename Output, typename Solution, typename SolutionBin>
    class TypedSolver : public Solver {

    public:

        /*
         * End:
         */

        void add_end_boolean(
            const bool* end
        ) override {
            parameters_.timer.add_end_boolean(end);
        }

        /*
         * Getters
         */

        size_t solutions_size() override {
            std::lock_guard<std::mutex> lock(solutions_mutex_);
            return solutions_.size();
        };

        json solutions_back() override {
            std::lock_guard<std::mutex> lock(solutions_mutex_);
            return std::move(solutions_.back());
        };

        /*
         * Read:
         */

        void read(
            basic_json<>& j
        ) override {

            if (j.contains("parameters")) {
                read_parameters(j["parameters"]);
            }

            if (j.contains("instance")) {
                read_instance(j["instance"], orig_builder_);
            }

        }

        /*
         * Optimize:
         */

        json optimize() override {
            return post_process(process(pre_process()));
        }

    protected:

        /** Packy parameters. */
        double length_truncate_factor_ = 1.0;
        int8_t length_truncate_precision_ = 3;

        /** Builders. */
        TypedBuilder<InstanceBuilder> orig_builder_;
        TypedBuilder<InstanceBuilder> usable_builder_;

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
         * Preprocess
         */

        virtual Instance pre_process() {

            // Build origin instance
            Instance orig_instance = orig_builder_.instance_builder().build();

            // Write instance to file for debug purpose with PackingSolver format
            if (!instance_path_.empty()) {
                orig_instance.write(instance_path_);  // Export instance to a file with PackingSolver 'write' method
            }

            /*
             * Test each item with not anytime sequential knapsack to know if it can fit in at least one bins
             */

            std::vector<ItemTypeId> usable_item_type_ids;
            std::vector<ItemTypeId> unusable_item_type_ids;

            for (ItemTypeId item_type_id = 0;
                 item_type_id < orig_instance.number_of_item_types();
                 ++item_type_id
            ) {

                auto& item_type = orig_instance.item_type(item_type_id);

                // Init a validator instance builder
                InstanceBuilder validator_builder;
                validator_builder.set_objective(Objective::Knapsack);
                validator_builder.set_parameters(orig_instance.parameters());

                // Copy item type (with only 1 copy)
                validator_builder.add_item_type(item_type, item_type.profit, 1);

                // Copy bin types
                for (BinTypeId bin_type_id = 0;
                     bin_type_id < orig_instance.number_of_bin_types();
                     ++bin_type_id
                ) {
                    const auto& bin_type = orig_instance.bin_type(bin_type_id);
                    validator_builder.add_bin_type(bin_type, 1);    // Force to use only one copy of each bin
                }

                // Build validator instance
                const Instance& validator_instance = validator_builder.build();

                OptimizeParameters validator_parameters;
                validator_parameters.timer = parameters_.timer;
                validator_parameters.linear_programming_solver_name = parameters_.linear_programming_solver_name;
                validator_parameters.optimization_mode = OptimizationMode::NotAnytimeSequential;
                validator_parameters.verbosity_level = 0;

                // Compute output
                Output output = pre_process_optimize(validator_instance, validator_parameters);

                if (output.solution_pool.best().full()) {
                    usable_item_type_ids.push_back(item_type_id);
                } else {
                    unusable_item_type_ids.push_back(item_type_id);
                }

            }

            if (unusable_item_type_ids.empty()) {

                // No unusable item type. Keep usable item_type_id and Tag all as usable
                for (auto orig_item_type_id : usable_item_type_ids) {
                    auto& item_type_meta = orig_builder_.item_type_meta(orig_item_type_id);
                    item_type_meta.usable_item_type_id = orig_item_type_id;     // Allows post_process to directly use item_type_id without a test
                    item_type_meta.usable = true;                               // Not necessary, already set in struct initialization
                }

                // Tag usable builder as not used
                usable_builder_.set_used(false);

            } else {

                // Tag unusable item types
                for (auto unusable_item_type_id : unusable_item_type_ids) {
                    auto& item_type_meta = orig_builder_.item_type_meta(unusable_item_type_id);
                    item_type_meta.usable = false;
                }

                /*
                 * Populate 'usable_builder_' from 'orig_builder_' attributes to send it to PackingSolver,
                 * but without unusable item types.
                 */

                // Copy objective
                usable_builder_.instance_builder().set_objective(orig_instance.objective());

                // Copy parameters
                usable_builder_.instance_builder().set_parameters(orig_instance.parameters());

                // Copy item types
                for (ItemTypeId usable_item_type_id = 0;
                     usable_item_type_id < usable_item_type_ids.size();
                     ++usable_item_type_id
                ) {
                    auto orig_item_type_id = usable_item_type_ids[usable_item_type_id];
                    auto& item_type = orig_instance.item_type(orig_item_type_id);
                    auto& item_type_meta = orig_builder_.item_type_meta(orig_item_type_id);
                    item_type_meta.usable_item_type_id = usable_item_type_id;
                    usable_builder_.instance_builder().add_item_type(item_type, item_type.profit, item_type_meta.copies);
                    usable_builder_.set_item_type_meta(usable_item_type_id, item_type_meta);
                }

                // Copy bin types
                for (BinTypeId bin_type_id = 0;
                     bin_type_id < orig_instance.number_of_bin_types();
                     ++bin_type_id
                ) {
                    const auto& bin_type = orig_instance.bin_type(bin_type_id);
                    const auto& bin_type_meta = orig_builder_.bin_type_meta(bin_type_id);
                    BinPos copies = bin_type_meta.copies == -1 && usable_item_type_ids.empty() ? 1 : bin_type_meta.copies;  // Retrieve copies from bin_typ_meta to keep -1 = infinite and force copies to 1 if no item types
                    usable_builder_.instance_builder().add_bin_type(bin_type, copies, bin_type.copies_min);
                    usable_builder_.set_bin_type_meta(bin_type_id, bin_type_meta);
                }

                // Tag usable builder as used
                usable_builder_.set_used(true);

                return std::move(usable_builder_.instance_builder().build());
            }

            // Nothing to exclude returns 'orig_instance' directly
            return std::move(orig_instance);
        }

        virtual Output pre_process_optimize(
            const Instance& instance,
            const OptimizeParameters& parameters
        ) = 0;

        /*
         * Process
         */

        virtual Output process(
            const Instance& instance
        ) = 0;

        /*
         * Postprocess
         */

        virtual json post_process(
            const Output& output
        ) {

            json j;
            write_best_solution(j, output, true);

            return std::move(j);
        }

        /*
         * Read:
         */

        Length read_length(
            const basic_json<>& j,
            const std::string& key,
            const Length default_length = 0
        ) const {
            return to_length(j.value(key, static_cast<double>(default_length)));
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
            if (j.contains("length_truncate_precision")) {
                length_truncate_precision_ = j.value("length_truncate_precision", 3);
                if (length_truncate_precision_ < 0) {
                    length_truncate_precision_ = 0;
                }
            }

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
                std::stringstream ss(j.value("linear_programming_solver", "highs"));
                ss >> linear_programming_solver_name;
                parameters_.linear_programming_solver_name = linear_programming_solver_name;
            } else {
                parameters_.linear_programming_solver_name = columngenerationsolver::SolverName::Highs;
            }
            if (j.contains("optimization_mode")) {
                OptimizationMode optimization_mode;
                std::stringstream ss(j.value("optimization_mode", "not-anytime-deterministic"));
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
                write_best_solution(j_solution, dynamic_cast<const Output&>(output), false);
                solutions_.push_back(j_solution);
            };


        };

        virtual void read_instance(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) {

            if (j.contains("objective")) {
                Objective objective;
                std::stringstream ss(j.value("objective", "default"));
                ss >> objective;
                builder.instance_builder().set_objective(objective);
            }
            if (j.contains("parameters")) {
                read_instance_parameters(j["parameters"], builder);
            }
            if (j.contains("item_types")) {
                read_item_types(j["item_types"], builder);
            }
            if (j.contains("bin_types")) {
                read_bin_types(j["bin_types"], builder);
            }

        }

        virtual void read_instance_parameters(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) = 0;

        virtual void read_item_types(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) {

            for (auto& j_item: j.items()) {
                auto& j_item_value = j_item.value();

                ItemTypeId item_type_id = read_item_type(j_item_value, builder);

                // Extract useful meta to keep them for post-processing

                ItemTypeMeta item_type_meta;
                item_type_meta.orig_item_type_id = item_type_id;
                item_type_meta.copies = j_item_value.value("copies", static_cast<ItemPos>(1));
                builder.set_item_type_meta(item_type_id, item_type_meta);

            }

        }

        virtual ItemTypeId read_item_type(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) = 0;

        virtual void read_bin_types(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) {

            for (auto& j_item: j.items()) {
                auto& j_item_value = j_item.value();

                BinTypeId bin_type_id = read_bin_type(j_item_value, builder);

                // Extract useful meta to keep them for post-processing

                BinTypeMeta bin_type_meta;
                bin_type_meta.copies = j_item_value.value("copies", static_cast<BinPos>(1));
                bin_type_meta.width_dbl = j_item_value.value("width", static_cast<double>(0));
                bin_type_meta.height_dbl = j_item_value.value("height", static_cast<double>(0));
                orig_builder_.set_bin_type_meta(bin_type_id, bin_type_meta);

            }

        }

        virtual BinTypeId read_bin_type(
            basic_json<>& j,
            TypedBuilder<InstanceBuilder>& builder
        ) = 0;

        /*
         * Write
         */

        virtual void write_best_solution(
            json& j,
            const Output& output,
            const bool final
        ) {

            const auto& solution = output.solution_pool.best();
            const auto& instance = solution.instance();
            auto& builder = usable_builder_.used() ? usable_builder_ : orig_builder_;

            j["time"] = output.time;

            j["full_waste"] = to_area_dbl(solution.full_waste());
            j["full_efficiency"] = solution.number_of_bins() > 0 ? 1 - solution.full_waste_percentage() : 0.0;
            j["cost"] = solution.cost();
            j["profit"] = solution.profit();

            j["number_of_items"] = solution.number_of_items();
            j["number_of_bins"] = solution.number_of_bins();

            BinTypeStats bin_type_stats;

            basic_json<>& j_bins = j["bins"] = json::array();
            for (BinPos bin_pos = 0; bin_pos < solution.number_of_different_bins(); ++bin_pos) {

                const auto& bin = solution.bin(bin_pos);
                const auto& bin_type = instance.bin_type(bin.bin_type_id);
                const BinTypeMeta& bin_type_meta = builder.bin_type_meta(bin.bin_type_id);

                basic_json<>& j_bin = j_bins.emplace_back(json{
                    {"bin_type_id", bin.bin_type_id},
                    {"copies",      bin.copies},
                });
                populate_best_solution_bin(j_bin, bin_pos, solution, bin, bin_type, bin_type_meta, builder);

                // Increment item copies stats
                bin_type_stats.item_copies_by_bin_type[bin.bin_type_id] += bin.copies * j_bin.value("number_of_items", 0);

            }

            basic_json<>& j_item_types_stats = j["item_types_stats"] = json::array();
            for (auto& [orig_item_type_id, item_type_meta] : orig_builder_.item_type_metas()) {

                const auto used_copies = item_type_meta.usable ? solution.item_copies(item_type_meta.usable_item_type_id) : 0;
                const auto unused_copies = item_type_meta.copies < 0 ? -1 : item_type_meta.copies - used_copies;

                basic_json<> j_item_type_stats = json{
                    {"item_type_id", item_type_meta.orig_item_type_id}
                };

                if (used_copies > 0) j_item_type_stats["used_copies"] = used_copies;
                if (unused_copies > 0 || used_copies == 0) j_item_type_stats["unused_copies"] = unused_copies;
                if (!item_type_meta.usable) j_item_type_stats["usable"] = item_type_meta.usable;

                if (item_type_meta.usable) {
                    populate_item_type_stats(j_item_type_stats, solution, item_type_meta.usable_item_type_id, final);
                }

                j_item_types_stats.emplace_back(j_item_type_stats);

            }

            basic_json<>& j_bin_types_stats = j["bin_types_stats"] = json::array();
            for (BinTypeId bin_type_id = 0; bin_type_id < instance.number_of_bin_types(); ++bin_type_id) {

                const auto& bin_type_meta = builder.bin_type_meta(bin_type_id);
                const auto used_copies = solution.bin_copies(bin_type_id);
                const auto unused_copies = bin_type_meta.copies < 0 ? -1 : bin_type_meta.copies - used_copies;

                basic_json<> j_bin_type_stats = json{
                    {"bin_type_id", bin_type_id},
                    {"item_copies", bin_type_stats.item_copies_by_bin_type[bin_type_id]}
                };

                if (used_copies > 0) j_bin_type_stats["used_copies"] = used_copies;
                if (unused_copies > 0 || used_copies == 0) j_bin_type_stats["unused_copies"] = unused_copies;

                populate_bin_type_stats(j_bin_type_stats, solution, bin_type_id, final);

                j_bin_types_stats.emplace_back(j_bin_type_stats);

            }

            if (messages_to_solution_) {
                j["messages"] = messages_stream_.str(); // Export PackingSolver output messages to the Packy solution
            }

            if (!certificate_path_.empty()) {
                solution.write(certificate_path_);  // Export solution to file with PackingSolver 'write' method
            }

        }

        virtual void populate_best_solution_bin(
            basic_json<>& j_bin,
            BinPos bin_pos,
            const Solution& solution,
            const SolutionBin& bin,
            const BinType& bin_type,
            const BinTypeMeta& bin_type_meta,
            TypedBuilder<InstanceBuilder>& builder
        ) = 0;

        virtual void populate_item_type_stats(
            basic_json<>& j_item_type_stats,
            const Solution& solution,
            const ItemTypeId item_type_id,
            const bool final
        ) {};

        virtual void populate_bin_type_stats(
            basic_json<>& j_bin_type_stats,
            const Solution& solution,
            const BinTypeId bin_type_id,
            const bool final
        ) {};

        /*
         * Utils:
         */

        Length to_length(
                const double length_dbl
        ) const {
            if (length_dbl > 0) {
                return static_cast<Length>(round(length_dbl * length_truncate_factor_, length_truncate_precision_));
            }
            return static_cast<Length>(length_dbl);
        }

        double to_length_dbl(
                const Length length,
                const int8_t precision = 16
        ) const {
            return round(static_cast<double>(length) / length_truncate_factor_, precision);
        }

        static double to_length_dbl(
                const double length_dbl,
                const int8_t precision = 16
        ) {
            return round(length_dbl, precision);
        }

        double to_area_dbl(
                const Area area,
                const int8_t precision = 16
        ) const {
            return round(static_cast<double>(area) / (length_truncate_factor_ * length_truncate_factor_), precision);
        }

        static double to_area_dbl(
                const double area_dbl,
                const int8_t precision = 16
        ) {
            return round(area_dbl, precision);
        }

        static double round(
                const double value,
                const int8_t precision = 16
        ) {
            return std::round(value * std::pow(10, precision)) / std::pow(10, precision);
        }


    };

    class RectangleSolver : public TypedSolver<rectangle::InstanceBuilder, rectangle::Instance, rectangle::ItemType, rectangle::BinType, rectangle::OptimizeParameters, rectangle::Output, rectangle::Solution, rectangle::SolutionBin> {

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
                basic_json<>& j,
                TypedBuilder<rectangle::InstanceBuilder>& builder
        ) override {

            if (j.contains("fake_trimming")) {
                fake_trimming_ = read_length(j, "fake_trimming", 0);
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = read_length(j, "fake_spacing", 0);
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j,
                TypedBuilder<rectangle::InstanceBuilder>& builder
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            const Profit profit = j.value("profit", static_cast<Profit>(-1));
            const ItemPos copies = j.value("copies", static_cast<ItemPos>(1));
            const bool oriented = j.value("oriented", false);
            const GroupId group_id = j.value("group_id", static_cast<GroupId>(0));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            ItemTypeId item_type_id = builder.instance_builder().add_item_type(
                    width,
                    height,
                    profit,
                    copies,
                    oriented
            );

            builder.instance_builder().set_item_type_group(
                item_type_id,
                group_id
            );

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j,
                TypedBuilder<rectangle::InstanceBuilder>& builder
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            const Profit cost = j.value("cost", static_cast<Profit>(-1));
            const BinPos copies = j.value("copies", static_cast<BinPos>(1));
            const BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (fake_trimming_ > 0) {
                if (width >= 0) width -= fake_trimming_ * 2;
                if (height >= 0) height -= fake_trimming_ * 2;
            }
            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }

            BinTypeId bin_type_id = builder.instance_builder().add_bin_type(
                    width,
                    height,
                    cost,
                    copies,
                    copies_min
            );

            // Defects

            if (j.contains("defects")) {
                for (auto& j_item: j["defects"].items()) {
                    read_defect(bin_type_id, j_item.value(), builder);
                }
            }

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j,
                TypedBuilder<rectangle::InstanceBuilder>& builder
        ) {

            Length x = read_length(j, "x", -1);
            Length y = read_length(j, "y", -1);
            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
                if (height >= 0) height += fake_spacing_;
            }
            if (fake_trimming_ > 0) {
                if (x >= 0) x -= fake_trimming_;
                if (y >= 0) y -= fake_trimming_;
            }

            builder.instance_builder().add_defect(
                    bin_type_id,
                    x,
                    y,
                    width,
                    height
            );

        }

    protected:

        rectangle::Output pre_process_optimize(
            const rectangle::Instance& instance,
            const rectangle::OptimizeParameters& parameters
        ) override {
            return std::move(rectangle::optimize(instance, parameters));
        }

        rectangle::Output process(
            const rectangle::Instance& instance
        ) override {
            return std::move(rectangle::optimize(instance, parameters_));
        }

        void populate_best_solution_bin(
            basic_json<>& j_bin,
            const BinPos bin_pos,
            const rectangle::Solution& solution,
            const rectangle::SolutionBin& bin,
            const rectangle::BinType& bin_type,
            const BinTypeMeta& bin_type_meta,
            TypedBuilder<rectangle::InstanceBuilder>& builder
        ) override {

            using namespace rectangle;

            Area bin_space = bin_type.rect.x * bin_type.rect.y;
            Area items_space = 0;
            for (const auto& item : bin.items) {
                const ItemType& item_type = solution.instance().item_type(item.item_type_id);
                items_space += item_type.space();
            }

            j_bin["space"] = to_area_dbl(bin_space);
            j_bin["waste"] = to_area_dbl(bin_space - items_space);
            j_bin["efficiency"] = static_cast<double>(items_space) / bin_space;

            // Add x_max and y_max attributes to the last bin
            if (bin_pos == solution.number_of_different_bins() - 1) {
                j_bin["x_max"] = to_length_dbl(fake_trimming_ + solution.x_max() - fake_spacing_);
                j_bin["y_max"] = to_length_dbl(fake_trimming_ + solution.y_max() - fake_spacing_);
            }

            basic_json<>& j_items = j_bin["items"] = json::array();
            for (const auto& item: bin.items) {

                const ItemType& item_type = solution.instance().item_type(item.item_type_id);
                const ItemTypeMeta& item_type_meta = builder.item_type_meta(item.item_type_id);

                if (item.rotate) {
                    j_items.emplace_back(json{
                            {"item_type_id", item_type_meta.orig_item_type_id},
                            {"x",            to_length_dbl(fake_trimming_ + item.bl_corner.x + item_type.rect.y - fake_spacing_)},
                            {"y",            to_length_dbl(fake_trimming_ + item.bl_corner.y)},
                            {"angle",        90.0}
                    });
                } else {
                    j_items.emplace_back(json{
                            {"item_type_id", item_type_meta.orig_item_type_id},
                            {"x",            to_length_dbl(fake_trimming_ + item.bl_corner.x)},
                            {"y",            to_length_dbl(fake_trimming_ + item.bl_corner.y)},
                            {"angle",        0}
                    });
                }

            }

            j_bin["number_of_items"] = j_items.size();

        }

    private:

        Length fake_trimming_ = 0;
        Length fake_spacing_ = 0;

    };

    class RectangleguillotineSolver : public TypedSolver<rectangleguillotine::InstanceBuilder, rectangleguillotine::Instance, rectangleguillotine::ItemType, rectangleguillotine::BinType, rectangleguillotine::OptimizeParameters, rectangleguillotine::Output, rectangleguillotine::Solution, rectangleguillotine::SolutionBin> {

    public:

        /*
         * Read:
         */

        void read_parameters(
                basic_json<>& j
        ) override {
            TypedSolver::read_parameters(j);

            if (j.contains("json_search_tree_path")) {
                parameters_.json_search_tree_path = j["json_search_tree_path"].get<std::string>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j,
                TypedBuilder<rectangleguillotine::InstanceBuilder>& builder
        ) override {

            using namespace rectangleguillotine;

            if (j.contains("use_column_generation_2")) {
                parameters_.use_column_generation_2 = j["use_column_generation_2"].get<bool>();
            }

            if (j.contains("number_of_stages")) {
                builder.instance_builder().set_number_of_stages(j["number_of_stages"].get<Counter>());
            }
            if (j.contains("cut_type")) {
                CutType cut_type;
                std::stringstream ss(j.value("cut_type", "non-exact"));
                ss >> cut_type;
                builder.instance_builder().set_cut_type(cut_type);
            }
            if (j.contains("first_stage_orientation")) {
                CutOrientation first_stage_orientation;
                std::stringstream ss(j.value("first_stage_orientation", "horizontal"));
                ss >> first_stage_orientation;
                builder.instance_builder().set_first_stage_orientation(first_stage_orientation);
            }
            if (j.contains("minimum_distance_1_cuts")) {
                builder.instance_builder().set_minimum_distance_1_cuts(read_length(j, "minimum_distance_1_cuts"));
            }
            if (j.contains("maximum_distance_1_cuts")) {
                builder.instance_builder().set_maximum_distance_1_cuts(read_length(j, "maximum_distance_1_cuts"));
            }
            if (j.contains("minimum_distance_2_cuts")) {
                builder.instance_builder().set_minimum_distance_2_cuts(read_length(j, "minimum_distance_2_cuts"));
            }
            if (j.contains("minimum_waste_length")) {
                builder.instance_builder().set_minimum_waste_length(read_length(j, "minimum_waste_length"));
            }
            if (j.contains("maximum_number_2_cuts")) {
                builder.instance_builder().set_maximum_number_2_cuts(j["maximum_number_2_cuts"].get<bool>());
            }
            if (j.contains("cut_through_defects")) {
                builder.instance_builder().set_cut_through_defects(j["cut_through_defects"].get<bool>());
            }
            if (j.contains("cut_thickness")) {
                builder.instance_builder().set_cut_thickness(read_length(j, "cut_thickness"));
            }

            if (j.contains("keep_width")) {
                keep_width_ = read_length(j, "keep_width");
            }
            if (j.contains("keep_height")) {
                keep_height_ = read_length(j, "keep_height");
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j,
                TypedBuilder<rectangleguillotine::InstanceBuilder>& builder
        ) override {

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            const Profit profit = j.value("profit", static_cast<Profit>(-1));
            const ItemPos copies = j.value("copies", static_cast<ItemPos>(-1));
            const bool oriented = j.value("oriented", false);
            const StackId stack_id = j.value("stack_id", static_cast<StackId>(-1));

            ItemTypeId item_type_id = builder.instance_builder().add_item_type(
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
                basic_json<>& j,
                TypedBuilder<rectangleguillotine::InstanceBuilder>& builder
        ) override {

            using namespace rectangleguillotine;

            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);
            const Profit cost = j.value("cost", static_cast<Profit>(-1));
            const BinPos copies = j.value("copies", static_cast<BinPos>(1));
            const BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            BinTypeId bin_type_id = builder.instance_builder().add_bin_type(
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

            builder.instance_builder().add_trims(
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
                    read_defect(bin_type_id, j_item.value(), builder);
                }
            }

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j,
                TypedBuilder<rectangleguillotine::InstanceBuilder>& builder
        ) {

            Length x = read_length(j, "x", -1);
            Length y = read_length(j, "y", -1);
            Length width = read_length(j, "width", -1);
            Length height = read_length(j, "height", -1);

            builder.instance_builder().add_defect(
                    bin_type_id,
                    x,
                    y,
                    width,
                    height
            );

        }

    protected:

        rectangleguillotine::Output pre_process_optimize(
            const rectangleguillotine::Instance& instance,
            const rectangleguillotine::OptimizeParameters& parameters
        ) override {
            return std::move(rectangleguillotine::optimize(instance, parameters));
        }

        rectangleguillotine::Output process(
            const rectangleguillotine::Instance& instance
        ) override {
            return std::move(rectangleguillotine::optimize(instance, parameters_));
        }

        json post_process(
            const rectangleguillotine::Output& output
            ) override {

            return std::move(TypedSolver::post_process(output));
        }

        void populate_best_solution_bin(
            basic_json<>& j_bin,
            const BinPos bin_pos,
            const rectangleguillotine::Solution& solution,
            const rectangleguillotine::SolutionBin& bin,
            const rectangleguillotine::BinType& bin_type,
            const BinTypeMeta& bin_type_meta,
            TypedBuilder<rectangleguillotine::InstanceBuilder>& builder
        ) override {

            using namespace rectangleguillotine;

            Area bin_space = bin_type.rect.area(); // Workaround to PackingSolver bin_type.space() function that subtract trims
            Area items_space = 0;
            for (const auto& node : bin.nodes) {
                if (node.item_type_id >= 0 && node.f >= 0) {
                    const ItemType& item_type = solution.instance().item_type(node.item_type_id);
                    items_space += item_type.rect.area();
                }
            }

            j_bin["space"] = to_area_dbl(bin_space);
            j_bin["waste"] = to_area_dbl(bin_space - items_space);
            j_bin["efficiency"] = static_cast<double>(items_space) / bin_space;

            Length cut_length = 0;
            int32_t number_of_leftovers_to_keep = 0;

            // Items, Leftovers & Cuts.
            basic_json<>& j_items = j_bin["items"] = json::array();
            basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
            basic_json<>& j_cuts = j_bin["cuts"] = json::array();
            for (const auto& node : bin.nodes) {

                if (node.item_type_id >= 0 && node.f >= 0) {

                    const ItemType& item_type = solution.instance().item_type(node.item_type_id);
                    const ItemTypeMeta& item_type_meta = builder.item_type_meta(node.item_type_id);

                    if (item_type.rect.w != node.r - node.l /* rotated */) {
                        j_items.push_back(json{
                                {"item_type_id", item_type_meta.orig_item_type_id},
                                {"x",            to_length_dbl(node.r)},
                                {"y",            to_length_dbl(node.b)},
                                {"angle",        90.0},
                        });
                    } else {
                        j_items.push_back(json{
                                {"item_type_id", item_type_meta.orig_item_type_id},
                                {"x",            to_length_dbl(node.l)},
                                {"y",            to_length_dbl(node.b)},
                                {"angle",        0.0},
                        });
                    }

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
                                    {"y",           to_length_dbl(node.b - solution.instance().parameters().cut_thickness)},
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
                                    {"x",           to_length_dbl(node.l - solution.instance().parameters().cut_thickness)},
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

    private:

        Length keep_width_ = std::numeric_limits<Length>::max();
        Length keep_height_ = std::numeric_limits<Length>::max();

    };

    class OnedimensionalSolver : public TypedSolver<onedimensional::InstanceBuilder, onedimensional::Instance, onedimensional::ItemType, onedimensional::BinType, onedimensional::OptimizeParameters, onedimensional::Output, onedimensional::Solution, onedimensional::SolutionBin> {

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
                basic_json<>& j,
                TypedBuilder<onedimensional::InstanceBuilder>& builder
        ) override {

            if (j.contains("fake_trimming")) {
                fake_trimming_ = read_length(j, "fake_trimming", 0);
            }
            if (j.contains("fake_spacing")) {
                fake_spacing_ = read_length(j, "fake_spacing", 0);
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j,
                TypedBuilder<onedimensional::InstanceBuilder>& builder
        ) override {

            Length width = read_length(j, "width", -1);
            const Profit profit = j.value("profit", static_cast<Profit>(-1));
            const ItemPos copies = j.value("copies", static_cast<ItemPos>(1));

            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

            ItemTypeId item_type_id = builder.instance_builder().add_item_type(
                    width,
                    profit,
                    copies
            );

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j,
                TypedBuilder<onedimensional::InstanceBuilder>& builder
        ) override {

            Length width = read_length(j, "width", -1);
            const Profit cost = j.value("cost", static_cast<Profit>(-1));
            const BinPos copies = j.value("copies", static_cast<BinPos>(1));
            const BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (fake_trimming_ > 0) {
                if (width >= 0) width -= fake_trimming_ * 2;
            }
            if (fake_spacing_ > 0) {
                if (width >= 0) width += fake_spacing_;
            }

            BinTypeId bin_type_id = builder.instance_builder().add_bin_type(
                    width,
                    cost,
                    copies,
                    copies_min
            );

            return bin_type_id;
        }

    protected:

        onedimensional::Output pre_process_optimize(
            const onedimensional::Instance& instance,
            const onedimensional::OptimizeParameters& parameters
        ) override {
            return std::move(onedimensional::optimize(instance, parameters));
        }

        onedimensional::Output process(
            const onedimensional::Instance& instance
        ) override {
            return std::move(onedimensional::optimize(instance, parameters_));
        }

        void populate_best_solution_bin(
            basic_json<>& j_bin,
            const BinPos bin_pos,
            const onedimensional::Solution& solution,
            const onedimensional::SolutionBin& bin,
            const onedimensional::BinType& bin_type,
            const BinTypeMeta& bin_type_meta,
            TypedBuilder<onedimensional::InstanceBuilder>& builder
        ) override {

            using namespace onedimensional;

            Length bin_space = bin_type.length;
            Length items_space = 0;
            for (const auto& item : bin.items) {
                const ItemType& item_type = solution.instance().item_type(item.item_type_id);
                items_space += item_type.space();
            }

            j_bin["space"] = to_length_dbl(bin_space);
            j_bin["waste"] = to_length_dbl(bin_space - items_space);
            j_bin["efficiency"] = static_cast<double>(items_space) / bin_space;

            // Items, Leftover & Cuts.
            basic_json<>& j_items = j_bin["items"] = json::array();
            basic_json<>& j_leftovers = j_bin["leftovers"] = json::array();
            basic_json<>& j_cuts = j_bin["cuts"] = json::array();
            if (fake_trimming_ > 0) {
                j_cuts.emplace_back(json{
                        {"depth",  0},
                        {"x",      to_length_dbl(fake_trimming_ - fake_spacing_)},
                        {"length", bin_type_meta.height_dbl}
                });
            }
            for (const auto& item: bin.items) {

                const ItemType& item_type = solution.instance().item_type(item.item_type_id);
                const ItemTypeMeta& item_type_meta = builder.item_type_meta(item.item_type_id);

                // Item
                j_items.emplace_back(json{
                        {"item_type_id", item_type_meta.orig_item_type_id},
                        {"x",            to_length_dbl(fake_trimming_ + item.start)},
                });

                // Cut
                if (item.start + item_type.length < bin_type.length) {

                    j_cuts.emplace_back(json{
                            {"depth",  1},
                            {"x",      to_length_dbl(fake_trimming_ + item.start + item_type.length - fake_spacing_)},
                            {"length", bin_type_meta.height_dbl}

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
            j_bin["cut_length"] = j_cuts.size() * bin_type_meta.height_dbl;

        }

    private:

        Length fake_trimming_ = 0;
        Length fake_spacing_ = 0;

    };

    class IrregularSolver : public TypedSolver<irregular::InstanceBuilder, irregular::Instance, irregular::ItemType, irregular::BinType, irregular::OptimizeParameters, irregular::Output, irregular::Solution, irregular::SolutionBin> {

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

            // Packy specific parameters

            if (j.contains("label_offsets")) {
                label_offsets_ = j["label_offsets"].get<bool>();
            }

        }

        void read_instance_parameters(
                basic_json<>& j,
                TypedBuilder<irregular::InstanceBuilder>& builder
        ) override {

            if (j.contains("item_item_minimum_spacing")) {
                builder.instance_builder().set_item_item_minimum_spacing(j["item_item_minimum_spacing"].get<irregular::LengthDbl>());
            }
            if (j.contains("item_bin_minimum_spacing")) {
                builder.instance_builder().set_item_bin_minimum_spacing(j["item_bin_minimum_spacing"].get<irregular::LengthDbl>());
            }

            if (j.contains("fake_trimming_y")) {
                fake_trimming_y_ = j["fake_trimming_y"].get<irregular::LengthDbl>();
            }

        }

        ItemTypeId read_item_type(
                basic_json<>& j,
                TypedBuilder<irregular::InstanceBuilder>& builder
        ) override {

            using namespace irregular;

            std::vector<ItemShape> item_shapes;
            if (j.contains("shapes")) {

                // Multiple item shape.
                for (auto& j_item: j["shapes"].items()) {
                    for (auto& item_shape : read_item_shape(j_item.value())) {
                        item_shapes.push_back(item_shape);
                    }
                }

            } else {

                // Single item shape.
                for (auto& item_shape : read_item_shape(j)) {
                    item_shapes.push_back(item_shape);
                }

            }

            const Profit profit = j.value("profit", static_cast<Profit>(-1));
            const ItemPos copies = j.value("copies", static_cast<ItemPos>(1));

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

            ItemTypeId item_type_id = builder.instance_builder().add_item_type(
                    item_shapes,
                    profit,
                    copies,
                    allowed_rotations
            );

            const bool allow_mirroring = j.value("allow_mirroring", false);
            builder.instance_builder().set_item_type_allow_mirroring(item_type_id, allow_mirroring);

            return item_type_id;
        }

        BinTypeId read_bin_type(
                basic_json<>& j,
                TypedBuilder<irregular::InstanceBuilder>& builder
        ) override {

            using namespace irregular;

            Shape shape = Shape::from_json(j);
            const Profit cost = j.value("cost", static_cast<Profit>(-1));
            const BinPos copies = j.value("copies", static_cast<BinPos>(1));
            const BinPos copies_min = j.value("copies_min", static_cast<BinPos>(0));

            if (/*shape.is_rectangle() && */fake_trimming_y_ > 0) {
                auto[min, max] = shape.compute_min_max();

                // TODO find a best way to enlarge the shape

                auto x = min.x;
                auto y = min.y;
                auto width = max.x - min.x;
                auto height = max.y - min.y + fake_trimming_y_ * 2;

                Shape fake_shape;
                ShapeElement element_1;
                ShapeElement element_2;
                ShapeElement element_3;
                ShapeElement element_4;
                element_1.type = ShapeElementType::LineSegment;
                element_2.type = ShapeElementType::LineSegment;
                element_3.type = ShapeElementType::LineSegment;
                element_4.type = ShapeElementType::LineSegment;
                element_1.start = {x, y};
                element_1.end = {x + width, y};
                element_2.start = {x + width, y};
                element_2.end = {x + width, y + height};
                element_3.start = {x + width, y + height};
                element_3.end = {x, y + height};
                element_4.start = {x, y + height};
                element_4.end = {x, y};
                fake_shape.elements.push_back(element_1);
                fake_shape.elements.push_back(element_2);
                fake_shape.elements.push_back(element_3);
                fake_shape.elements.push_back(element_4);

                shape = fake_shape;

            }

            BinTypeId bin_type_id = builder.instance_builder().add_bin_type(
                    shape,
                    cost,
                    copies,
                    copies_min
            );

            // Defects

            if (j.contains("defects")) {
                for (auto& j_item: j["defects"].items()) {
                    read_defect(bin_type_id, j_item.value(), builder);
                }
            }

            return bin_type_id;
        }

        void read_defect(
                BinTypeId bin_type_id,
                basic_json<>& j,
                TypedBuilder<irregular::InstanceBuilder>& builder
        ) {

            using namespace irregular;

            const DefectTypeId type = j.value("defect_type", static_cast<DefectTypeId>(-1));
            const ShapeWithHoles shape = ShapeWithHoles::from_json(j);

            builder.instance_builder().add_defect(
                    bin_type_id,
                    type,
                    shape
            );

        }

    protected:

        irregular::Output pre_process_optimize(
            const irregular::Instance& instance,
            const irregular::OptimizeParameters& parameters
        ) override {
            return std::move(irregular::optimize(instance, parameters));
        }

        irregular::Output process(
            const irregular::Instance& instance
        ) override {
            return std::move(irregular::optimize(instance, parameters_));
        }

        void populate_best_solution_bin(
            basic_json<>& j_bin,
            const BinPos bin_pos,
            const irregular::Solution& solution,
            const irregular::SolutionBin& bin,
            const irregular::BinType& bin_type,
            const BinTypeMeta& bin_type_meta,
            TypedBuilder<irregular::InstanceBuilder>& builder
        ) override {

            using namespace irregular;

            AreaDbl bin_space = bin_type.space();
            AreaDbl items_space = 0;
            for (const auto& item : bin.items) {
                const ItemType& item_type = solution.instance().item_type(item.item_type_id);
                items_space += item_type.space();
            }

            j_bin["space"] = to_area_dbl(bin_space);
            j_bin["waste"] = to_area_dbl(bin_space - items_space);
            j_bin["efficiency"] = items_space / bin_space;

            // Add x_min, x_max and y_min, y_max attributes to the last bin
            if (bin_pos == solution.number_of_different_bins() - 1) {
                j_bin["x_min"] = to_length_dbl(solution.x_min());
                j_bin["x_max"] = to_length_dbl(solution.x_max());
                j_bin["y_min"] = to_length_dbl(solution.y_min());
                j_bin["y_max"] = to_length_dbl(solution.y_max());
            }

            basic_json<>& j_items = j_bin["items"] = json::array();
            for (const auto& item: bin.items) {

                ItemTypeMeta& item_type_meta = builder.item_type_meta(item.item_type_id);

                j_items.emplace_back(json{
                    {"item_type_id", item_type_meta.orig_item_type_id},
                    {"x", to_length_dbl(item.bl_corner.x)},
                    {"y", to_length_dbl(item.bl_corner.y - fake_trimming_y_)},
                    {"angle", item.angle}, // Returns angle in degrees
                    {"mirror", item.mirror}
                });

            }

            j_bin["number_of_items"] = j_items.size();
            j_bin["number_of_leftovers"] = 0;
            j_bin["number_of_cuts"] = 0;

        }

        void populate_item_type_stats(
            basic_json<>& j_item_type_stats,
            const irregular::Solution& solution,
            const ItemTypeId item_type_id,
            const bool final
        ) override {

            if (final && label_offsets_) {

                auto item_type = solution.instance().item_type(item_type_id);

                irregular::ItemShape largest_item_shape;
                std::pair<shape::Point, shape::Point> min_max;

                if (item_type.shapes.size() > 1) {

                    // The item contains multiple item shapes.
                    // Try to find the largest and compute min max of all.

                    min_max = {
                        {std::numeric_limits<irregular::LengthDbl>::infinity(), std::numeric_limits<irregular::LengthDbl>::infinity()},
                        {-std::numeric_limits<irregular::LengthDbl>::infinity(), -std::numeric_limits<irregular::LengthDbl>::infinity()}
                    };
                    shape::AreaDbl max_area = 0;
                    for (const auto& item_shape : item_type.shapes) {

                        // Compute min max
                        auto shape_min_max = item_shape.shape_orig.compute_min_max();
                        if (shape_min_max.first.x < min_max.first.x) min_max.first.x = shape_min_max.first.x;
                        if (shape_min_max.first.y < min_max.first.y) min_max.first.y = shape_min_max.first.y;
                        if (shape_min_max.second.x > min_max.second.x) min_max.second.x = shape_min_max.second.x;
                        if (shape_min_max.second.y > min_max.second.y) min_max.second.y = shape_min_max.second.y;

                        shape::AreaDbl area = item_shape.shape_orig.shape.compute_area();
                        for (const auto& hole : item_shape.shape_orig.holes) {
                            area -= hole.compute_area();
                        }

                        if (area > max_area) {
                            max_area = area;
                            largest_item_shape = item_shape;
                        }

                    }

                } else {

                    // Use the first item shape
                    largest_item_shape = item_type.shapes.front();

                    // Compute min max
                    min_max = largest_item_shape.shape_orig.compute_min_max();

                }

                // Compute item shapes size
                auto item_length = min_max.second.x - min_max.first.x;
                auto item_width = min_max.second.y - min_max.first.y;

                // Find label position
                shape::Point label_position = shape::find_label_position(largest_item_shape.shape_orig);

                // Write the label offset (relative to the item shapes center)
                j_item_type_stats["label_offset"] = json{
                    {"x", to_length_dbl(label_position.x - (min_max.first.x + item_length / 2.0))},
                    {"y", to_length_dbl(label_position.y - (min_max.first.y + item_width / 2.0))},
                };

            }

        };

    private:

        irregular::LengthDbl fake_trimming_y_ = false;

        bool label_offsets_ = false;

        static std::vector<irregular::ItemShape> read_item_shape(
                basic_json<>& j
        ) {

            using namespace irregular;

            ShapeWithHoles shape = ShapeWithHoles::from_json(j);
            std::vector<ShapeWithHoles> fixed_shapes = fix_self_intersections(shape);
            std::vector<ItemShape> item_shapes;

            for (const auto& fixed_shape: fixed_shapes) {
                item_shapes.emplace_back(ItemShape{fixed_shape});
            }

            return std::move(item_shapes);
        }

    };

}
