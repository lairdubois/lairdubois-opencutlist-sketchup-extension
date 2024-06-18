#include "packy.hpp"
#include "packy.structs.hpp"

#include <utility>

namespace Packy {

  // ShapeDef and Shape

  ShapeDef::ShapeDef(int id, int count, int rotations, Clipper2Lib::Paths64 paths) :
    id(id),
    count(count),
    rotations(rotations),
    paths(std::move(paths)),
    item_type_id(0) {}

  ShapeDef::~ShapeDef() = default;


  Shape::Shape(ShapeDef* def) :
    def(def),
    x(0),
    y(0),
    angle(0) {}

  Shape::~Shape() = default;


  // Cut

  Cut::Cut(int16_t depth, int64_t x1, int64_t y1, int64_t x2, int64_t y2) :
    depth(depth),
    x1(x1),
    y1(y1),
    x2(x2),
    y2(y2) {}

  Cut::~Cut() = default;


  // BinDef and Bin

  BinDef::BinDef(int id, int count, int64_t length, int64_t width, int type) :
    id(id),
    count(count),
    length(length),
    width(width),
    type(type),
    bin_type_id(0) {}

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

  std::string Solution::format() {
    return "solution.unused_bins.size = " + std::to_string(this->unused_bins.size()) + "\n"
           "solution.packed_bins.size = " + std::to_string(this->packed_bins.size()) + "\n"
           "solution.unplaced_shapes.size = " + std::to_string(this->unplaced_shapes.size()) + "\n";
  }

  // -- Converters

  size_t GetCShapeArrayLen() {
    return 4 /* id, x, y, angle */;
  }

  size_t GetCShapesArrayLen(const Shapes &shapes) {
    return 1 /* Number of shapes */ + shapes.size() * GetCShapeArrayLen();
  }

  size_t GetCCutArrayLen() {
    return 5 /* depth, x1, y1, x2, y2 */;
  }

  size_t GetCCutsArrayLen(const Cuts &cuts) {
    return 1 /* Number of cuts */ + cuts.size() * GetCCutArrayLen();
  }

  size_t GetCBinArrayLen(const Bin &bin) {
    return 1 /* id */ + GetCShapesArrayLen(bin.shapes) + GetCCutsArrayLen(bin.cuts);
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

  void ConvertCutToCCut(const Cut &cut, int64_t *&v) {

    /*

     CCut
      |attr  |attr  |attr  |attr  |attr
      |depth |x1    |y1    |x2    |y2

     */

    *v++ = static_cast<int64_t>(cut.depth);
    *v++ = static_cast<int64_t>(cut.x1);
    *v++ = static_cast<int64_t>(cut.y1);
    *v++ = static_cast<int64_t>(cut.x2);
    *v++ = static_cast<int64_t>(cut.y2);

  }

  void ConvertCutsToCCuts(const Cuts &cuts, int64_t *&v) {

    /*

     CCuts
      |counter|cut1  |cut2  |...|cutN
      |N      |      |      |...|

      N = Number of cuts

     */

    *v++ = static_cast<int64_t>(cuts.size());
    for (auto &cut : cuts) {
      ConvertCutToCCut(cut, v);
    }

  }

  void ConvertBinToCBin(const Bin &bin, int64_t *&v) {

    /*

     CBin
      |attr   |shapes |cuts
      |id     |       |

     */

    *v++ = static_cast<int64_t>(bin.def->id);
    ConvertShapesToCShapes(bin.shapes, v);
    ConvertCutsToCCuts(bin.cuts, v);

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