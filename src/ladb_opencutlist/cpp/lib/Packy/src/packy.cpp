#include "clipper2/clipper.wrapper.hpp"

#include "packy.hpp"
#include "optimizer_builder.hpp"

#include <string>
#include <stdexcept>
#include <thread>
#include <mutex>

#include <nlohmann/json.hpp>

using namespace Clipper2Lib;
using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

std::mutex mtx;

std::string solution_output;
std::string advance_output;

void optimize_task(char* input) {

  mtx.lock();
  solution_output.clear();
  advance_output.clear();
  mtx.unlock();

  try {

    std::stringstream stream;
    stream << input;

    OptimizerBuilder optimizer_builder;
    Optimizer& optimizer = optimizer_builder.build(stream);

    json j_output = optimizer.optimize();

    mtx.lock();
    solution_output = j_output.dump();
    mtx.unlock();

  } catch (const std::exception &e) {
    mtx.lock();
    solution_output = json{{"error", "Packy: " + ((std::string) e.what())}}.dump();
    mtx.unlock();
  } catch (...) {
    mtx.lock();
    solution_output = json{{"error", "Packy: Unknow error"}}.dump();
    mtx.unlock();
  }

}

DLL_EXPORTS void c_optimize_start(char* input) {

  std::thread thread(optimize_task, input);
  thread.detach();

}

DLL_EXPORTS char* c_optimize_advance() {

  mtx.lock();
  bool running = solution_output.empty();
  mtx.unlock();

  if (running) {
    advance_output.clear();
    advance_output = json{{"running", true}}.dump();
    return (char*)advance_output.c_str();
  } else {
    return (char*)solution_output.c_str();
  }
}

DLL_EXPORTS char* c_version() {
  return (char *)PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif