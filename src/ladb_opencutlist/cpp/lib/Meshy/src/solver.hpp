#pragma once

#include <manifold/manifold.h>
#include <nlohmann/json_fwd.hpp>

#include <iosfwd>
#include <string>
#include <vector>

namespace Meshy {

    enum class Operation
    {
        Union,
        Subtraction,
        Intersection,
    };

    std::istream& operator>>(
            std::istream& in,
            Operation& operation
    );

    std::ostream& operator<<(
            std::ostream& os,
            Operation operation
    );

    class Solver {

    public:

        /*
         * Build:
         */

        static Solver build(
                const std::string& filepath
        );

        static Solver build(
                std::istream& is
        );

        /*
         * Solve:
         */

        void read(
                const nlohmann::json& j
        );

        nlohmann::json operate();

    private:

        Operation operation_ = Operation::Union;

        // Skip mesh validation when the caller guarantees closed, consistently
        // oriented operands.
        bool validate_ = true;

        // SketchUp merge tolerance (1/1000 inch) : geometry closer than this cannot
        // exist as separate entities in SketchUp. Drives plane canonicalization,
        // snapping and nudging.
        double tolerance_ = 0.001;

        std::vector<manifold::MeshGL64> src_meshes_;
        std::vector<manifold::MeshGL64> cut_meshes_;

    };

}