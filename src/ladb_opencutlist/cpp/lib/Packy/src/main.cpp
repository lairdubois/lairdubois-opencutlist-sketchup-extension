#include <iostream>
#include <future>

#include "packy.hpp"
#include "solver_builder.hpp"

using namespace Packy;
using namespace nlohmann;

int main() {

    std::cout << "---------------------------------" << std::endl;
    std::cout << "             PACKY" << std::endl;
    std::cout << "---------------------------------" << std::endl;

//  try {

    SolverBuilder optimizer_builder;
    Solver& optimizer = (*optimizer_builder.build(std::string("input.json")));

    json j_ouput = optimizer.optimize();

    std::cout << "###################################" << std::endl;
    std::cout << j_ouput.dump(1, ' ') << std::endl;
    std::cout << "###################################" << std::endl;

//  } catch(const std::exception& e) {
//    std::cout << "\033[1;31mError: " + std::string(e.what()) + "\033[0m" << std::endl;
//  } catch( ... ) {
//    std::cout << "\033[1;31mUnknow Error\033[0m" << std::endl;
//  }

    return 0;
}
