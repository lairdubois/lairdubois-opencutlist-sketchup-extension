#include "clipper2/clipper.wrapper.hpp"

#include "packy.hpp"
#include "packy.structs.hpp"
#include "packy.engine.hpp"

#include <algorithm>
#include <string>
#include <stdexcept>
#include <sstream>

using namespace Clipper2Lib;
using namespace Packy;

#ifdef __cplusplus
extern "C" {
#endif

ShapeDefs shape_defs;
BinDefs bin_defs;

Packy::Solution solution;

std::string message;

DLL_EXPORTS void c_clear() {
  bin_defs.clear();
  shape_defs.clear();
  solution.clear();
  message.clear();
}

DLL_EXPORTS void c_append_bin_def(int id, int count, int64_t length, int64_t width, int type) {
  bin_defs.emplace_back(id, count, length, width, type);
}

DLL_EXPORTS void c_append_shape_def(int id, int count, int rotations, const int64_t* cpaths) {
  shape_defs.emplace_back(id, count, rotations, ConvertCPathsToPaths(cpaths));
}

DLL_EXPORTS char* c_execute_rectangle(int64_t spacing, int64_t trimming) {

  try {

    RectangleEngine engine;
    engine.run(shape_defs, bin_defs, spacing, trimming, solution, message);

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

DLL_EXPORTS char* c_execute_rectangleguillotine(int64_t spacing, int64_t trimming) {

  try {

    RectangleGuillotineEngine engine;
    engine.run(shape_defs, bin_defs, spacing, trimming, solution, message);

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

DLL_EXPORTS char* c_execute_irregular(int64_t spacing, int64_t trimming) {

  try {

    IrregularEngine engine;
    engine.run(shape_defs, bin_defs, spacing, trimming, solution, message);

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

DLL_EXPORTS char* c_execute_onedimensional(int64_t spacing, int64_t trimming) {

  try {

    OneDimensionalEngine engine;
    engine.run(shape_defs, bin_defs, spacing, trimming, solution, message);

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

DLL_EXPORTS int64_t* c_get_solution() {
  return ConvertSolutionToCSolution(solution);
}


DLL_EXPORTS void c_dispose_array64(const int64_t* p) {
  delete[] p;
}


DLL_EXPORTS char* c_version() {
  return (char *)PACKY_VERSION;
}

#ifdef __cplusplus
}
#endif