#include "clipper2/clipper.wrapper.hpp"

#include "nesty.hpp"
#include "nesty.structs.hpp"
#include "nesty.engine.hpp"

#include <algorithm>
#include <string>
#include <stdexcept>

using namespace Clipper2Lib;
using namespace Nesty;

#ifdef __cplusplus
extern "C" {
#endif

ShapeDefs shape_defs;
BinDefs bin_defs;

Nesty::Solution solution;

std::string message;

DLL_EXPORTS void c_clear() {
  bin_defs.clear();
  shape_defs.clear();
  solution.clear();
  message.clear();
}

DLL_EXPORTS void c_append_shape_def(int id, int count, const int64_t* cpaths) {
  shape_defs.emplace_back(id, count, ConvertCPathsToPaths(cpaths));
}

DLL_EXPORTS void c_append_bin_def(int id, int count, int64_t length, int64_t width, int type) {
  bin_defs.emplace_back(id, count, length, width, type);
}

DLL_EXPORTS char* c_execute_nesting(int64_t spacing, int64_t trimming, int rotations) {

  try {

    RectangleGuillotineEngine engine;
    engine.run(shape_defs, bin_defs, spacing, trimming, rotations, solution);

    message.clear();
    message = "-- START NESTY MESSAGE --\n"
            "bin_defs.size = " + std::to_string(bin_defs.size()) + "\n"
            "shape_defs.size = " + std::to_string(shape_defs.size()) + "\n"
            "-------------------------\n"
            "spacing = " + std::to_string(spacing) + "\n"
            "trimming = " + std::to_string(trimming) + "\n"
            "rotations = " + std::to_string(rotations) + "\n"
            "-------------------------\n"
            "solution.unused_bins.size = " + std::to_string(solution.unused_bins.size()) + "\n"
            "solution.packed_bins.size = " + std::to_string(solution.packed_bins.size()) + "\n"
            "solution.unplaced_shapes.size = " + std::to_string(solution.unplaced_shapes.size()) + "\n"
            "-- END NESTY MESSAGE --\n";

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
  return (char *)NESTY_VERSION;
}

#ifdef __cplusplus
}
#endif