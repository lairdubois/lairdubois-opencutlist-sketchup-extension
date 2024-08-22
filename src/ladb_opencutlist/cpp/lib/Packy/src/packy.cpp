#include "clipper2/clipper.wrapper.hpp"

#include "packy.hpp"
#include "optimizer_builder.hpp"

#include <string>
#include <stdexcept>
#include <thread>
#include <mutex>
#include <future>
#include <chrono>

#include <nlohmann/json.hpp>

using namespace Clipper2Lib;
using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

std::mutex mtx;

std::shared_future<json> optimize_future_;
std::string optimize_str_output_;

DLL_EXPORTS void c_optimize_start(char* input) {

  optimize_future_ = std::async(std::launch::async, [input]{
    json j_ouput;

    try {

      std::stringstream is;
      is << input;

      OptimizerBuilder optimizer_builder;
      Optimizer& optimizer = (*optimizer_builder.build(is));

      j_ouput = optimizer.optimize();

    } catch(const std::exception& e) {
      j_ouput["error"] = "\033[1;31mError: " + std::string(e.what()) + "\033[0m";
    } catch( ... ) {
      j_ouput["error"] = "\033[1;31mUnknow Error\033[0m";
    }

    return std::move(j_ouput);
  }).share();

}

DLL_EXPORTS char* c_optimize_advance() {

  std::future_status status = optimize_future_.wait_for(std::chrono::milliseconds(0));
  if (status == std::future_status::ready) {
    optimize_str_output_ = optimize_future_.get().dump();
    return (char*)optimize_str_output_.c_str();
  } else {
    optimize_str_output_ = json{{"running", true}, {"status", status}}.dump();
    return (char*)optimize_str_output_.c_str();
  }

}

DLL_EXPORTS char* c_version() {
  return (char *)PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif