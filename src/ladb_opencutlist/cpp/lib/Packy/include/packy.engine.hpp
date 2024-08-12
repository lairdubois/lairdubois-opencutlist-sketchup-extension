#ifndef PACKY_ENGINE_HPP
#define PACKY_ENGINE_HPP

#include "packy.structs.hpp"

namespace Packy {

  class RectangleEngine {

  public:

    bool run(
            ItemDefs &item_def,
            BinDefs &bin_defs,
            char *c_objective,
            double c_spacing,
            double c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class RectangleGuillotineEngine {

  public:

    bool run(
            ItemDefs &item_def,
            BinDefs &bin_defs,
            char *c_objective,
            char *c_cut_type,
            char *c_first_stage_orientation,
            double c_spacing,
            double c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class IrregularEngine {

  public:

    bool run(
            ItemDefs &item_def,
            BinDefs &bin_defs,
            char *c_objective,
            double c_spacing,
            double c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

  class OneDimensionalEngine {

  public:

    bool run(
            ItemDefs &item_def,
            BinDefs &bin_defs,
            char *c_objective,
            double c_spacing,
            double c_trimming,
            int verbosity_level,
            Solution &solution,
            std::string &message
    );

  };

}

#endif // PACKY_ENGINE_HPP
