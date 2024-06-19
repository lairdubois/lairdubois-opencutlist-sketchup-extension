#ifndef PACKY_ENGINE_H
#define PACKY_ENGINE_H

#include "packy.structs.hpp"

namespace Packy {

  class RectangleEngine {

  public:

    bool run(
            ShapeDefs &shape_defs,
            BinDefs &bin_defs,
            char *c_objective,
            int64_t c_spacing,
            int64_t c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class RectangleGuillotineEngine {

  public:

    bool run(
            ShapeDefs &shape_defs,
            BinDefs &bin_defs,
            char *c_objective,
            char *c_cut_type,
            char *c_first_stage_orientation,
            int64_t c_spacing,
            int64_t c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class IrregularEngine {

  public:

    bool run(
            ShapeDefs &shape_defs,
            BinDefs &bin_defs,
            char *c_objective,
            int64_t c_spacing,
            int64_t c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class OneDimensionalEngine {

  public:

    bool run(
            ShapeDefs &shape_defs,
            BinDefs &bin_defs,
            char *c_objective,
            int64_t c_spacing,
            int64_t c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

}

#endif // PACKY_ENGINE_H
