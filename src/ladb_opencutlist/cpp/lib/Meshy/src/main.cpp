#include <fstream>
#include <iostream>

#include <nlohmann/json.hpp>
#include <boost/program_options.hpp>

#include "solver.hpp"

using namespace Meshy;
using namespace nlohmann;

namespace po = boost::program_options;

int main(int argc, char* argv[]) {

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

    Solver solver = Solver::build(input_path);

    json j_output = solver.operate();

    std::string output_path = (vm.count("output"))? vm["output"].as<std::string>() : "";
    if (output_path.empty() || output_path == "stdout") {
        std::cout << j_output.dump(1, ' ') << std::endl;
    } else {
        std::ofstream ofs;
        ofs.open(output_path);
        ofs << j_output.dump(1, ' ');
        ofs.close();
    }

    return EXIT_SUCCESS;
}