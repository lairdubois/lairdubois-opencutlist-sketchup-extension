#include "clipper2/clipper.wrapper.h"

#include "nesty.h"
#include "nesty.engine.h"

#include <algorithm>
#include <string>

using namespace Nesty;

size_t GetCShapeArrayLen() {
  return 4 /* id, x, y, rotation */;
}

size_t GetCShapesArrayLen(const Shapes &shapes) {
  return 1 /* Number of shapes */ + shapes.size() * GetCShapeArrayLen();
}

size_t GetCBinArrayLen(const Bin &bin) {
  return 1 /* id */ + GetCShapesArrayLen(bin.shapes);
}

size_t GetCBinsArrayLen(const Bins &bins) {
  int array_len = 1 /* Number of bins */;
  for (auto &bin : bins) {
    array_len += GetCBinArrayLen(bin);
  }
  return array_len;
}

void ConvertShapeToCShape(const Shape &shape, int64_t *&v) {

  /*

   CShape
    |attr  |attr  |attr  |attr
    |id    |x     |y     |rotation

   */

  *v++ = static_cast<int64_t>(shape.def->id);
  *v++ = static_cast<int64_t>(shape.x);
  *v++ = static_cast<int64_t>(shape.y);
  *v++ = static_cast<int64_t>(shape.rotation);

}

void ConvertShapesToCShapes(const Shapes &shapes, int64_t *&v) {

  /*

   CShapes
    |counter|shape1|shape2|...|shapeN
    |N      |      |      |...|

    N = Number of shapes

   */

  *v++ = static_cast<int64_t>(shapes.size());
  for (auto &shape : shapes) {
    ConvertShapeToCShape(shape, v);
  }

}

void ConvertBinToCBin(const Bin &bin, int64_t *&v) {

  /*

   CBin
    |attr   |shapes
    |id     |

   */

  *v++ = static_cast<int64_t>(bin.def->id);
  ConvertShapesToCShapes(bin.shapes, v);

}

void ConvertBinsToCBins(const Bins &bins, int64_t *&v) {

  /*

   CBins
    |attr   |bin1|bin2|...|binN
    |N      |    |    |...|

    N = Number of bins

   */

  *v++ = static_cast<int64_t>(bins.size());
  for (auto &bin : bins) {
    ConvertBinToCBin(bin, v);
  }

}

int64_t* ConvertSolutionToCSolution(const Solution &solution) {

  /*

   CSolution
    |counter|unused_bins|packed_bins|unplaced_shapes
    |L      |           |           |

    L = Array length

   */

  size_t array_len = 1 /* Array length */ + GetCBinsArrayLen(solution.unused_bins) + GetCBinsArrayLen(solution.packed_bins) + GetCShapesArrayLen(solution.unplaced_shapes);
  int64_t *result = new int64_t[array_len], *v = result;
  *v++ = static_cast<int64_t>(array_len);
  ConvertBinsToCBins(solution.unused_bins, v);
  ConvertBinsToCBins(solution.packed_bins, v);
  ConvertShapesToCShapes(solution.unplaced_shapes, v);

  return result;
}

#ifdef __cplusplus
extern "C" {
#endif

ShapeDefs shape_defs;
BinDefs bin_defs;

Solution solution;

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

DLL_EXPORTS void c_append_shape_def(int id, int count, const int64_t* cpaths) {
  shape_defs.emplace_back(id, count, ConvertCPathsToPaths(cpaths));
}

DLL_EXPORTS char* c_execute_nesting(int64_t spacing, int64_t trimming) {

  DummyEngine engine;
  engine.Execute(shape_defs, bin_defs, spacing, trimming, solution);

  message.clear();
  message = "-- START NESTY MESSAGE --\n"
            "spacing=" + std::to_string(spacing) + "\n"
            "trimming=" + std::to_string(trimming) + "\n"
            "bin_defs.size=" + std::to_string(bin_defs.size()) + "\n"
            "shape_defs.size=" + std::to_string(shape_defs.size()) + "\n"
            "solution.unused_bins.size=" + std::to_string(solution.unused_bins.size()) + "\n"
            "solution.packed_bins.size=" + std::to_string(solution.packed_bins.size()) + "\n"
            "solution.unplaced_shapes.size=" + std::to_string(solution.unplaced_shapes.size()) + "\n"
            "-- END NESTY MESSAGE --\n";
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