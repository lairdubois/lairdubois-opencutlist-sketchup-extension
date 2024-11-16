#include <iostream>

#include "packy.hpp"
#include "solver_builder.hpp"

using namespace Packy;
using namespace nlohmann;

int main(int argc, char* argv[], char* envp[]) {

    // Default input filename
    std::string infile = "input.json";

    // The program takes a single argument the input filename
    if (argc == 2) {
        infile = argv[1];
    }

    if (!std::filesystem::exists(infile)) {
        std::cout << "Input file does not exist: " << infile << std::endl;
        exit(EXIT_FAILURE);
    }

    try {

        SolverBuilder optimizer_builder;
        Solver& optimizer = (*optimizer_builder.build(infile));

        json j_output = optimizer.optimize();

        std::cout << j_output.dump(1, ' ') << std::endl;

    } catch (const std::exception& e) {
        std::cout << "Internal error: " << std::string(e.what()) << std::endl;
    }

    return EXIT_SUCCESS;
}
