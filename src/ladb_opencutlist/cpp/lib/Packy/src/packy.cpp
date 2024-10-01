#include "packy.hpp"
#include "optimizer_builder.hpp"

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
static OptimizerPtr optimizer_ptr_;
static int last_send_solution_pos_ = 0;

DLL_EXPORTS char* c_optimize_start(
        char* s_input
) {

    optimize_future_ = std::async(std::launch::async, [s_input]() {
        json j_ouput;

        try {

            std::stringstream is;
            is << s_input;

            // Create the optimizer
            OptimizerBuilder optimizer_builder;
            optimizer_ptr_ = optimizer_builder.build(is);
            Optimizer& optimizer = *optimizer_ptr_;

            // Link the cancelled boolean
            optimizer.parameters().timer.set_end_boolean(&optimize_cancelled_);

            // Reset cancelled status
            optimize_cancelled_ = false;

            // Reset last_known_solution_pos_
            last_send_solution_pos_ = 0;

            // Run!
            j_ouput = optimizer.optimize();

        } catch (const std::exception& e) {
            j_ouput["error"] = e.what();
        } catch (...) {
            j_ouput["error"] = "Unknow Error";
        }

        // Reset optimizer ptr
        optimizer_ptr_ = nullptr;

        return std::move(j_ouput);
    }).share();

    optimize_str_output_ = json{{"running", true}}.dump();

    return (char*) optimize_str_output_.c_str();
}

DLL_EXPORTS char* c_optimize_advance() {

    std::future_status status = optimize_future_.wait_for(std::chrono::milliseconds(0));
    if (status == std::future_status::ready) {
        if (optimize_cancelled_) {
            optimize_str_output_ = json{{"cancelled", true}}.dump();
        } else {
            optimize_str_output_ = optimize_future_.get().dump();
        }
    } else {
        json j = json{{"running", true}};
        if (optimizer_ptr_ != nullptr && (*optimizer_ptr_).solutions().size() > last_send_solution_pos_) {
            j["solution"] = (*optimizer_ptr_).solutions().back();
            last_send_solution_pos_ = (int) (*optimizer_ptr_).solutions().size();
        }
        optimize_str_output_ = j.dump();
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