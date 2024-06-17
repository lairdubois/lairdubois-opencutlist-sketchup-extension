#ifndef PACKY_ENGINE_H
#define PACKY_ENGINE_H

#include "packy.structs.hpp"

namespace Packy {

  class DummyEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution, std::string &message);

  };

  class RectangleEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution, std::string &message);

  };

  class RectangleGuillotineEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution, std::string &message);

  };

  class IrregularEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution, std::string &message);

  };

  class OneDimensionalEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution, std::string &message);

  };

}

#endif // PACKY_ENGINE_H
