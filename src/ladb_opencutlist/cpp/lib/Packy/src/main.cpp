#include <iostream>

#include "solver_builder.hpp"

#include <boost/program_options.hpp>

#include "shape/pole_of_inaccessibility.hpp"

using namespace Packy;
using namespace nlohmann;

namespace po = boost::program_options;

int main(int argc, char* argv[]) {

    // POI debug

    shape::Shape shape = shape::build_shape({{0, 0}, {1, 0}, {1, 1}, {0, 1}});
    std::vector holes = {
        shape::build_shape({{0.25, 0.25}, {0.75, 0.25}, {0.75, 0.75}, {0.25, 0.75}})
    };
    shape::Point poi = shape::approximate_pole_of_inaccessibility(shape, holes);

    std::cout << "POI = " << poi.x << " " << poi.y << std::endl;

    // POI debug

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "Produce help message")

        ("input,i", po::value<std::string>(), "Input path (default: input.json)")
        ("output,o", po::value<std::string>(), "Output path (default: stdout)")
    ;

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    if (vm.count("help")) {
        std::cout << desc << std::endl;
        return EXIT_FAILURE;
    }
    try {
        po::notify(vm);
    } catch (const po::required_option& e) {
        std::cout << desc << std::endl;
        return EXIT_FAILURE;
    }

    std::string input_path = (vm.count("input"))? vm["input"].as<std::string>() : "input.json";

    try {

        SolverBuilder optimizer_builder;
        Solver& optimizer = (*optimizer_builder.build(input_path));

        json j_output = optimizer.optimize();

        std::string output_path = (vm.count("output"))? vm["output"].as<std::string>() : "";
        if (output_path.empty() || output_path == "stdout") {
            std::cout << j_output.dump(1, ' ') << std::endl;
        } else {
            std::ofstream ofs;
            ofs.open(output_path);
            ofs << j_output.dump(1, ' ');
            ofs.close();
        }

    } catch (const std::exception& e) {
        std::cerr << "Internal error: " << std::string(e.what()) << std::endl;
    }

    return EXIT_SUCCESS;
}