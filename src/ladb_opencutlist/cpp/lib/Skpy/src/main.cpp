#include <fstream>
#include <iostream>

#include "skp_header_reader.hpp"

#include <boost/program_options.hpp>

using namespace Skpy;

namespace po = boost::program_options;

int main(int argc, char* argv[]) {

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "Produce help message")

        ("input,i", po::value<std::string>(), "Input JSON file path (default: input.json)")
        ("output,o", po::value<std::string>(), "Output JSON file path (default: stdout)")
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

    std::string input_path = vm.count("input") ? vm["input"].as<std::string>() : "input.json";

    json j_output = SkpHeaderReader::run(input_path);

    std::string output_path = vm.count("output") ? vm["output"].as<std::string>() : "";
    if (output_path.empty() || output_path == "stdout") {
        std::cout << j_output.dump(1, ' ') << std::endl;
    } else {
        std::ofstream ofs(output_path);
        ofs << j_output.dump(1, ' ');
    }

    return EXIT_SUCCESS;
}