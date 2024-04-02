#include "nesty.h"
#include "nesty.structs.h"

#include <utility>

namespace Nesty {

  // ShapeDef and Shape

  ShapeDef::ShapeDef(int id, int count, Clipper2Lib::Paths64 paths) :
    id(id),
    count(count),
    paths(std::move(paths)) {}

  ShapeDef::~ShapeDef() = default;


  Shape::Shape(ShapeDef* def) :
    def(def),
    x(0),
    y(0),
    angle(0) {}

  Shape::~Shape() = default;


  // BinDef and Bin

  BinDef::BinDef(int id, int count, int64_t length, int64_t width, int type) :
    id(id),
    count(count),
    length(length),
    width(width),
    type(type) {}

  BinDef::~BinDef() = default;


  Bin::Bin(BinDef* def) :
    def(def) {}

  Bin::~Bin() = default;


  // Solution

  Solution::Solution() = default;
  Solution::~Solution() = default;

  void Solution::clear() {
    this->unused_bins.clear();
    this->packed_bins.clear();
    this->unplaced_shapes.clear();
  }

  // -- Converters

  size_t GetCShapeArrayLen() {
    return 4 /* id, x, y, angle */;
  }

  size_t GetCShapesArrayLen(const Shapes &shapes) {
    return 1 /* Number of shapes */ + shapes.size() * GetCShapeArrayLen();
  }

  size_t GetCBinArrayLen(const Bin &bin) {
    return 1 /* id */ + GetCShapesArrayLen(bin.shapes);
  }

  size_t GetCBinsArrayLen(const Bins &bins) {
    size_t array_len = 1 /* Number of bins */;
    for (auto &bin : bins) {
      array_len += GetCBinArrayLen(bin);
    }
    return array_len;
  }

  void ConvertShapeToCShape(const Shape &shape, int64_t *&v) {

    /*

     CShape
      |attr  |attr  |attr  |attr
      |id    |x     |y     |angle

     */

    *v++ = static_cast<int64_t>(shape.def->id);
    *v++ = static_cast<int64_t>(shape.x);
    *v++ = static_cast<int64_t>(shape.y);
    *v++ = static_cast<int64_t>(shape.angle);

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

}