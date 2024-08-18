#pragma once

#include "optimizer.hpp"

using namespace packingsolver;
using namespace nlohmann;

namespace Packy {

  class OptimizerBuilder {

  public:

    /** Destructor. */
    ~OptimizerBuilder() {
      delete optimizer_ptr_;
    }

    /*
     * Build:
     */
    Optimizer& build(std::string path) {

      std::ifstream file(path);
      if (!file.good()) {
        throw std::runtime_error("Unable to open file \"" + path + "\".");
      }

      return build(file);
    }

    Optimizer& build(std::istream& stream) {

      nlohmann ::json j;
      stream >> j;

      if (j.contains("problem_type")) {

        ProblemType problem_type;
        std::stringstream ss(j.value("problem_type", ""));
        ss >> problem_type;

        delete optimizer_ptr_;

        if (problem_type == ProblemType::Rectangle) {
          optimizer_ptr_ = new RectangleOptimizer();
        } else if (problem_type == ProblemType::RectangleGuillotine) {
          optimizer_ptr_ = new RectangleguillotineOptimizer();
        } else if (problem_type == ProblemType::OneDimensional) {
          optimizer_ptr_ = new OnedimensionalOptimizer();
        } else if (problem_type == ProblemType::Irregular) {
          optimizer_ptr_ = new IrregularOptimizer();
        } else {
          throw std::runtime_error("Unavailable problem type \"" + ss.str() + "\".");
        }

        (*optimizer_ptr_).read(j);

      } else {
        throw std::invalid_argument("Missing \"problem_type\" parameter.");
      }

      return (*optimizer_ptr_);
    }

  private:

    Optimizer* optimizer_ptr_ = nullptr;

  };

}
