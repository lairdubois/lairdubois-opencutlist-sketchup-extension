#ifndef NESTY_SHAPE_H
#define NESTY_SHAPE_H

#include "clipper2/clipper.h"

namespace Nesty {

  struct ShapeDef {

    ShapeDef(int id, int count, Clipper2Lib::Paths64 paths) {
      this->id = id;
      this->count = count;
      this->paths = paths;
    }
    ~ShapeDef() {};

    int id;
    int count;

    Clipper2Lib::Paths64 paths;

  };

  struct Shape {

    Shape(ShapeDef* def) {
      this->def = def;
    }
    ~Shape() {};

    ShapeDef* def = nullptr;

    int64_t x, y;
    int64_t rotation;

  };

  using ShapeDefs = std::vector<ShapeDef>;
  using Shapes = std::vector<Shape>;

  struct BinDef {

    BinDef(int id, int count, int64_t length, int64_t width, int type) {
      this->id = id;
      this->count = count;
      this->length = length;
      this->width = width;
      this->type = type;
    }
    ~BinDef() {};

    int id = 0;
    int count = 0;

    int64_t length = 0;
    int64_t width = 0;

    int type = 0;

  };

  struct Bin {

    Bin(BinDef* def) {
      this->def = def;
    }
    ~Bin() {};

    BinDef* def = nullptr;

    Shapes shapes;

  };

  using BinDefs = std::vector<BinDef>;
  using Bins = std::vector<Bin>;

  struct Solution {

    Solution() {}
    ~Solution() {};

    Bins unused_bins;
    Bins packed_bins;

    Shapes unplaced_shapes;

    void clear() {
      this->unused_bins.clear();
      this->packed_bins.clear();
      this->unplaced_shapes.clear();
    }

  };

}

#endif // NESTY_SHAPE_H
