#include "packy.hpp"
#include "solver_builder.hpp"

#include <string>
#include <stdexcept>
#include <thread>
#include <future>

#include <nlohmann/json.hpp>

using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

static std::shared_future<json> optimize_future_;
static std::string optimize_str_output_;
static bool optimize_cancelled_ = false;
static SolverPtr solver_ptr_;
static size_t last_send_solution_pos_ = 0;

DLL_EXPORTS char* c_optimize_start(
        char* s_input
) {

    optimize_future_ = std::async(std::launch::async, [s_input]() {
        json j_ouput;

        try {

            std::stringstream is;
            is << s_input;

            // Create the solver
            SolverBuilder solver_builder;
            solver_ptr_ = solver_builder.build(is);
            Solver& solver = *solver_ptr_;

            // Link the cancelled boolean
            solver.parameters().timer.add_end_boolean(&optimize_cancelled_);

            // Reset cancelled status
            optimize_cancelled_ = false;

            // Reset last_known_solution_pos_
            last_send_solution_pos_ = 0;

            // Run!
            j_ouput["solution"] = solver.optimize();

        } catch (const std::exception& e) {
            j_ouput["error"] = e.what();
        } catch (...) {
            j_ouput["error"] = "Unknown Error";
        }

        // Reset optimizer ptr
        solver_ptr_ = nullptr;

        return std::move(j_ouput);
    }).share();

    optimize_str_output_ = json{{"running", true}}.dump();

    return (char*) optimize_str_output_.c_str();
}

DLL_EXPORTS char* c_optimize_advance() {

    std::future_status status = optimize_future_.wait_for(std::chrono::milliseconds(0));
    if (status == std::future_status::ready) {
        if (optimize_cancelled_ && last_send_solution_pos_ == 0) {
            optimize_str_output_ = json{{"cancelled", true}}.dump();
        } else {
            optimize_str_output_ = optimize_future_.get().dump();
        }
    } else {
        json j_output = json{{"running", true}};
        if (solver_ptr_ != nullptr) {
            size_t solutions_size = (*solver_ptr_).solutions_size();
            if (solutions_size > last_send_solution_pos_) {
                j_output["solution"] = (*solver_ptr_).solutions_back();
                last_send_solution_pos_ = solutions_size;
            }
        }
        optimize_str_output_ = j_output.dump();
    }

    return (char*) optimize_str_output_.c_str();
}

DLL_EXPORTS void c_optimize_cancel() {
    optimize_cancelled_ = true;
}

DLL_EXPORTS char* c_version() {
    return (char*) PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif