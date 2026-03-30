#pragma once

#include "solver.hpp"

#include <fstream>
#include <sstream>

using namespace nlohmann;

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

            if (j.contains("problem_type")) {

                ProblemType problem_type;
                std::stringstream ss(j.value("problem_type", ""));
                ss >> problem_type;

                if (problem_type == ProblemType::Debug) {
                    solver_ptr_ = std::make_shared<DebugSolver>();
                } else {
                    throw std::runtime_error("Unavailable problem type \"" + ss.str() + "\".");
                }

                (*solver_ptr_).read(j);

            } else {
                throw std::invalid_argument("Missing \"problem_type\" parameter.");
            }

            return solver_ptr_;
        }

    private:

        /** Optimizer. */
        SolverPtr solver_ptr_;

    };

}
