#ifndef NESTY_ENGINE_H
#define NESTY_ENGINE_H

#include "nesty.structs.h"

namespace Nesty {

  class DummyEngine {

  public:

    bool run(ShapeDefs &shape_defs, BinDefs &bin_defs, int64_t spacing, int64_t trimming, Solution &solution);

  };

}

#endif //NESTY_ENGINE_H
