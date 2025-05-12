#include <fstream>
#include <iostream>
#include <string>

#include "xly.hpp"

#include <nlohmann/json.hpp>
#include <boost/program_options.hpp>

using namespace nlohmann;

namespace po = boost::program_options;

int main(int argc, char* argv[]) {

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "Produce help message")

        ("input,i", po::value<std::string>(), "Input path (default: input.json)")
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

    std::ifstream ifs(input_path);
    if (!ifs.good()) {
        throw std::runtime_error("Unable to open file path \"" + input_path + "\".");
    }

    std::stringstream buffer;
    buffer << ifs.rdbuf();

    char* str_output = c_write_to_xlsx(buffer.str().c_str());

    std::cout << str_output << std::endl;

    return EXIT_SUCCESS;
}
