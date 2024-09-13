#pragma once

#include "optimizer.hpp"

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

    class OptimizerBuilder {

    public:

        /*
         * Build:
         */

        OptimizerPtr build(
                const std::string& filepath
        ) {

            std::ifstream file(filepath);
            if (!file.good()) {
                throw std::runtime_error("Unable to open file path \"" + filepath + "\".");
            }

            return build(file);
        }

        OptimizerPtr build(
                std::istream& is
        ) {

            nlohmann::json j;
            is >> j;

            if (j.contains("problem_type")) {

                ProblemType problem_type;
                std::stringstream ss(j.value("problem_type", ""));
                ss >> problem_type;

                if (problem_type == ProblemType::Rectangle) {
                    optimizer_ptr_ = std::make_shared<RectangleOptimizer>();
                } else if (problem_type == ProblemType::RectangleGuillotine) {
                    optimizer_ptr_ = std::make_shared<RectangleguillotineOptimizer>();
                } else if (problem_type == ProblemType::OneDimensional) {
                    optimizer_ptr_ = std::make_shared<OnedimensionalOptimizer>();
                } else if (problem_type == ProblemType::Irregular) {
                    optimizer_ptr_ = std::make_shared<IrregularOptimizer>();
                } else {
                    throw std::runtime_error("Unavailable problem type \"" + ss.str() + "\".");
                }

                (*optimizer_ptr_).read(j);

            } else {
                throw std::invalid_argument("Missing \"problem_type\" parameter.");
            }

            return optimizer_ptr_;
        }

    private:

        /** Optimizer. */
        OptimizerPtr optimizer_ptr_;

    };

}
