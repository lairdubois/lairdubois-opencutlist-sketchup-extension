#ifndef PACKY_ENGINE_H
#define PACKY_ENGINE_H

#include "packy.structs.hpp"

namespace Packy {

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

  class OneDimensionalEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, int rotations, Solution &solution);

  };

}

#endif // PACKY_ENGINE_H
