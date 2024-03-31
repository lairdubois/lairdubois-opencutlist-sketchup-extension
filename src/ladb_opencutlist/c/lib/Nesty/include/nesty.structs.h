#ifndef NESTY_SHAPE_H
#define NESTY_SHAPE_H

#include "clipper2/clipper.h"

namespace Nesty {

  struct ShapeDef {

    ShapeDef(int id, int count, Clipper2Lib::Paths64 paths);
    ~ShapeDef() = default;

    int id;
    int count;

    Clipper2Lib::Paths64 paths;

  };

  struct Shape {

    explicit Shape(ShapeDef* def);
    ~Shape() = default;

    ShapeDef* def = nullptr;

    int64_t x = 0;
    int64_t y = 0;
    int64_t rotation = 0;

  };

  using ShapeDefs = std::vector<ShapeDef>;
  using Shapes = std::vector<Shape>;

  struct BinDef {

    BinDef(int id, int count, int64_t length, int64_t width, int type);
    ~BinDef() = default;

    int id = 0;
    int count = 0;

    int64_t length = 0;
    int64_t width = 0;

    int type = 0;

  };

  struct Bin {

    explicit Bin(BinDef* def);
    ~Bin() = default;

    BinDef* def = nullptr;

    Shapes shapes;

  };

  using BinDefs = std::vector<BinDef>;
  using Bins = std::vector<Bin>;

  struct Solution {

    Solution() = default;
    ~Solution() = default;

    Bins unused_bins;
    Bins packed_bins;

    Shapes unplaced_shapes;

    void clear();

  };

  // -- Converters

  size_t GetCShapeArrayLen();
  size_t GetCShapesArrayLen(const Shapes &shapes);
  size_t GetCBinArrayLen(const Bin &bin);
  size_t GetCBinsArrayLen(const Bins &bins);

  void ConvertShapeToCShape(const Shape &shape, int64_t *&v);
  void ConvertShapesToCShapes(const Shapes &shapes, int64_t *&v);
  void ConvertBinToCBin(const Bin &bin, int64_t *&v);
  void ConvertBinsToCBins(const Bins &bins, int64_t *&v);
  int64_t* ConvertSolutionToCSolution(const Solution &solution);

}

#endif // NESTY_SHAPE_H
