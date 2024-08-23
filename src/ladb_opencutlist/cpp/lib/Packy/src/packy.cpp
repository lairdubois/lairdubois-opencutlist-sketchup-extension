#include "clipper2/clipper.wrapper.hpp"

#include "packy.hpp"
#include "optimizer_builder.hpp"

#include <string>
#include <stdexcept>
#include <thread>
#include <future>

#include <nlohmann/json.hpp>

using namespace Clipper2Lib;
using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

static std::shared_future<json> optimize_future_;
static std::string optimize_str_output_;
static bool optimize_cancelled_ = false;

DLL_EXPORTS void c_optimize_start(char* s_input) {

  optimize_future_ = std::async(std::launch::async, [s_input]{
    json j_ouput;

    try {

      std::stringstream is;
      is << s_input;

      // Create the optimizer
      OptimizerBuilder optimizer_builder;
      Optimizer& optimizer = (*optimizer_builder.build(is));

      // Link the cancelled boolean
      optimizer.parameters().timer.set_end_boolean(&optimize_cancelled_);

      // Reset cancelled status
      optimize_cancelled_ = false;

      // Run!
      j_ouput = optimizer.optimize();

    } catch(const std::exception& e) {
      j_ouput["error"] = e.what();
    } catch( ... ) {
      j_ouput["error"] = "Unknow Error";
    }

    return std::move(j_ouput);
  }).share();

}

DLL_EXPORTS char* c_optimize_advance() {

  std::future_status status = optimize_future_.wait_for(std::chrono::milliseconds(0));
  if (status == std::future_status::ready) {
    if (optimize_cancelled_) {
      optimize_str_output_ = json{{"cancelled", true}}.dump();
      return (char*)optimize_str_output_.c_str();
    } else {
      optimize_str_output_ = optimize_future_.get().dump();
      return (char*)optimize_str_output_.c_str();
    }
  } else {
    optimize_str_output_ = json{{"running", true}}.dump();
    return (char*)optimize_str_output_.c_str();
  }

}

DLL_EXPORTS void c_optimize_stop() {
  optimize_cancelled_ = true;
}

DLL_EXPORTS char* c_version() {
  return (char *)PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif