#pragma once

#include "solver.hpp"

#include <fstream>

namespace Meshy {

    class SolverBuilder {

    public:

        /*
         * Build:
         */

        SolverPtr build(
                const std::string& filepath
        ) {

            std::ifstream ifs(filepath);
            if (!ifs.good()) {
                throw std::runtime_error("Unable to open file path \"" + filepath + "\".");
            }

            return build(ifs);
        }

        SolverPtr build(
                std::istream& is
        ) {

            json j;
            is >> j;

            if (j.contains("solver_type")) {

                SolverType solver_type;
                std::stringstream ss(j.value("solver_type", ""));
                ss >> solver_type;

                if (solver_type == SolverType::Manifold) {
                    solver_ptr_ = std::make_shared<ManifoldSolver>();
                } else {
                    throw std::runtime_error("Unavailable problem type \"" + ss.str() + "\".");
                }

                (*solver_ptr_).read(j);

            } else {
                throw std::invalid_argument("Missing \"solver_type\" parameter.");
            }

            return solver_ptr_;
        }

    private:

        /** Optimizer. */
        SolverPtr solver_ptr_;

    };

}
