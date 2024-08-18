#include "clipper2/clipper.wrapper.hpp"

#include "packy.hpp"
#include "packy.structs.hpp"
#include "packy.engine.hpp"
#include "optimizer_builder.hpp"

#include <algorithm>
#include <string>
#include <stdexcept>
#include <thread>

#include <nlohmann/json.hpp>

using namespace Clipper2Lib;
using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

ItemDefs item_defs;
BinDefs bin_defs;

Packy::Solution solution;

std::string message;

DLL_EXPORTS void c_clear() {
  bin_defs.clear();
  item_defs.clear();
  solution.clear();
  message.clear();
}

DLL_EXPORTS void c_append_bin_def(int id, int count, double length, double width, int type) {
  bin_defs.emplace_back(id, count, length, width, type);
}

DLL_EXPORTS void c_append_item_def(int id, int count, int rotations, double* cpaths) {
  item_defs.emplace_back(id, count, rotations, ConvertCPaths(cpaths));
}


DLL_EXPORTS char* c_execute_rectangle(char *c_objective, double c_spacing, double c_trimming, int verbosity_level) {

  try {

    RectangleEngine engine;
    engine.run(item_defs, bin_defs, c_objective, c_spacing, c_trimming, verbosity_level, solution, message);

    message = "-- START PACKY MESSAGE --\n" + message + "-- END PACKY MESSAGE --\n";

  } catch(const std::exception &e) {
    message.clear();
    message = "Error: " + (std::string)e.what();
  } catch( ... ) {
    message.clear();
    message = "Unknow Error";
  }

  return (char*)message.c_str();
}

DLL_EXPORTS char* c_execute_rectangleguillotine(char *c_objective, char *c_cut_type, char *c_first_stage_orientation, double c_spacing, double c_trimming, int verbosity_level) {

  try {

    RectangleGuillotineEngine engine;
    engine.run(item_defs, bin_defs, c_objective, c_cut_type, c_first_stage_orientation, c_spacing, c_trimming, verbosity_level, solution, message);

    message = "-- START PACKY MESSAGE --\n" + message + "-- END PACKY MESSAGE --\n";

  } catch(const std::exception &e) {
    message.clear();
    message = "Error: " + (std::string)e.what();
  } catch( ... ) {
    message.clear();
    message = "Unknow Error";
  }

  return (char*)message.c_str();
}

DLL_EXPORTS char* c_execute_irregular(char *c_objective, double c_spacing, double c_trimming, int verbosity_level) {

  try {

    IrregularEngine engine;
    engine.run(item_defs, bin_defs, c_objective, c_spacing, c_trimming, verbosity_level, solution, message);

    message = "-- START PACKY MESSAGE --\n" + message + "-- END PACKY MESSAGE --\n";

  } catch(const std::exception &e) {
    message.clear();
    message = "Error: " + (std::string)e.what();
  } catch( ... ) {
    message.clear();
    message = "Unknow Error";
  }

  return (char*)message.c_str();
}

DLL_EXPORTS char* c_execute_onedimensional(char *c_objective, double c_spacing, double c_trimming, int verbosity_level) {

  try {

    OneDimensionalEngine engine;
    engine.run(item_defs, bin_defs, c_objective, c_spacing, c_trimming, verbosity_level, solution, message);

    message = "-- START PACKY MESSAGE --\n" + message + "-- END PACKY MESSAGE --\n";

  } catch(const std::exception &e) {
    message.clear();
    message = "Error: " + (std::string)e.what();
  } catch( ... ) {
    message.clear();
    message = "Unknow Error";
  }

  return (char*)message.c_str();
}


DLL_EXPORTS double* c_get_solution() {
  return ConvertSolutionToCSolution(solution);
}


DLL_EXPORTS void c_dispose_array_d(const double* p) {
  delete[] p;
}


DLL_EXPORTS char* c_optimize(char* input) {

  message.clear();

  try {

    std::stringstream stream;
    stream << input;

    OptimizerBuilder optimizer_builder;
    Optimizer& optimizer = optimizer_builder.build(stream);

    json output = optimizer.optimize();

    message = output.dump();

  } catch(const std::exception &e) {
    message = json {{"error", "Packy: " + ((std::string)e.what())}}.dump();
  } catch( ... ) {
    message = json {{"error", "Packy: Unknow error"}}.dump();
  }

  return (char*)message.c_str();
}

DLL_EXPORTS char* c_version() {
  return (char *)PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif