#ifndef NESTY_SHAPE_H
#define NESTY_SHAPE_H

#include "clipper2/clipper.h"

namespace Nesty {

  // ShapeDef and Shape

  struct ShapeDef {

    ShapeDef(int id, int count, Clipper2Lib::Paths64 paths);
    ~ShapeDef();

    int id;
    int count;

    Clipper2Lib::Paths64 paths;

    int16_t item_type_id;

  };

  struct Shape {

    explicit Shape(ShapeDef* def);
    ~Shape();

    ShapeDef* def;

    int64_t x;
    int64_t y;
    int64_t angle;

  };

  using ShapeDefs = std::vector<ShapeDef>;
  using Shapes = std::vector<Shape>;

  // BinDef and Bin

  struct BinDef {

    BinDef(int id, int count, int64_t length, int64_t width, int type);
    ~BinDef();

    int id;
    int count;

    int64_t length;
    int64_t width;

    int type;

    int16_t bin_type_id;

  };

  struct Bin {

    explicit Bin(BinDef* def);
    ~Bin();

    BinDef* def;

    Shapes shapes;

  };

  using BinDefs = std::vector<BinDef>;
  using Bins = std::vector<Bin>;

  // Solution

  struct Solution {

    Solution();
    ~Solution();

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
