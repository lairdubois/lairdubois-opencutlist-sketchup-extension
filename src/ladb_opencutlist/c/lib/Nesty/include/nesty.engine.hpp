#ifndef NESTY_ENGINE_H
#define NESTY_ENGINE_H

#include "nesty.structs.hpp"

namespace Nesty {

  class DummyEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution);

  };

  class RectangleEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution);

  };

  class RectangleGuillotineEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution);

  };

  class IrregularEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution);

  };

}

#endif // NESTY_ENGINE_H
