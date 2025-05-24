#include "packy.hpp"
#include "solver_builder.hpp"

#include <string>
#include <thread>
#include <future>

#include <nlohmann/json.hpp>

using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

static std::string str_output_;

struct Run {
    int id = 0;
    std::shared_future<json> optimize_future;
    bool optimize_cancelled = false;
    SolverPtr solver_ptr = nullptr;
    size_t last_send_solution_pos = 0;
};

static int last_run_id = 0;
static std::unordered_map<int, Run> runs_;

DLL_EXPORTS char* c_optimize_start(
        const char* s_input
) {

    // Increment run id
    int run_id = last_run_id++;

    // Create a new run structure in the run map
    Run& run = runs_[run_id];

    // Define run future
    run.optimize_future = std::async(std::launch::async, [s_input, &run]() {
        json j_ouput = json{
            {"run_id", run.id}
        };

        try {

            std::stringstream is;
            is << s_input;

            // Create the solver
            SolverBuilder solver_builder;
            run.solver_ptr = solver_builder.build(is);
            Solver& solver = *run.solver_ptr;

            // Add the cancelled boolean
            solver.add_end_boolean(&run.optimize_cancelled);

            // Reset cancelled status
            run.optimize_cancelled = false;

            // Reset last_known_solution_pos
            run.last_send_solution_pos = 0;

            // Run!
            j_ouput["solution"] = solver.optimize();

        } catch (const std::exception& e) {
            j_ouput["error"] = e.what();
        } catch (...) {
            j_ouput["error"] = "Unknown Error";
        }

        // Reset solver ptr
        run.solver_ptr = nullptr;

        return std::move(j_ouput);
    }).share();

    str_output_ = json{
        {"running", true},
        {"run_id", run_id},
    }.dump();

    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_optimize_advance(
        int run_id
) {

    if (runs_.find(run_id) == runs_.end()) {

        // Run doesn't exist
        str_output_ = json{
            {"error", "Unknown run_id=" + std::to_string(run_id)}
        }.dump();

    } else {

        Run& run = runs_.at(run_id);

        std::future_status status = run.optimize_future.wait_for(std::chrono::milliseconds(0));
        if (status == std::future_status::ready) {
            if (run.optimize_cancelled && run.last_send_solution_pos == 0) {

                // Run is cancelled, notify it in the returned output
                str_output_ = json{
                    {"cancelled", true},
                    {"run_id", run_id}
                }.dump();

            } else {

                // Get output from the final computation
                str_output_ = run.optimize_future.get().dump();

                // Delete run
                runs_.erase(run_id);

            }
        } else {

            // Run is running
            json j_output = json{
                {"running", true},
                {"run_id", run_id}
            };
            if (run.solver_ptr != nullptr) {
                size_t solutions_size = (*run.solver_ptr).solutions_size();
                if (solutions_size > run.last_send_solution_pos) {
                    j_output["solution"] = (*run.solver_ptr).solutions_back();
                    run.last_send_solution_pos = solutions_size;
                }
            }
            str_output_ = j_output.dump();

        }

    }

    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_optimize_cancel(
        int run_id
) {

    if (runs_.find(run_id) == runs_.end()) {

        // Run doesn't exist
        str_output_ = json{
            {"error", "Unknown run_id=" + std::to_string(run_id)}
        }.dump();

    } else {

        Run& run = runs_.at(run_id);

        // Ask run to cancel
        run.optimize_cancelled = true;

        // Run is cancelled, notify it in the returned output
        str_output_ = json{
            {"cancelled", true},
            {"run_id", run_id}
        }.dump();

    }

    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_optimize_cancel_all() {
    std::vector<int> run_ids_to_erase;
    for (auto& [run_id, run] : runs_) {

        // Ask run to cancel
        run.optimize_cancelled = true;

        std::future_status status = run.optimize_future.wait_for(std::chrono::milliseconds(0));
        if (status == std::future_status::ready) {
            run_ids_to_erase.emplace_back(run_id);
        }

    }
    for (auto run_id : run_ids_to_erase) {
        runs_.erase(run_id);
    }
    str_output_ = json{
        {"number_of_erased_runs", run_ids_to_erase.size()},
    }.dump();

    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_version() {
    return const_cast<char*>(PACKY_VERSION);
}

#ifdef __cplusplus
}
#endif