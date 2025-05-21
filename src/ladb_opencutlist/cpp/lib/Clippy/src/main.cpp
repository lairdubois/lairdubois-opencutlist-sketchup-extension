#include <iostream>

#include <boost/program_options.hpp>

#include "clipper.svg.h"
#include "clipper.svg.utils.h"
#include "clipper2/clipper.wrapper.hpp"

using namespace Clipper2Lib;

namespace po = boost::program_options;

int main(int argc, char* argv[]) {

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help,h", "Produce help message")

        ("input,i", po::value<std::string>(), "Input path (default: input.svg)")
        ("output,o", po::value<std::string>(), "Output path (default: output.svg)")
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

    std::string input_path = (vm.count("input"))? vm["input"].as<std::string>() : "input.svg";
    std::string output_path = (vm.count("input"))? vm["input"].as<std::string>() : "output.svg";


    FillRule fill_rule = FillRule::EvenOdd;

    PathsD subject = {
        { {0.0, 0.0}, {10.0, 10.0}, {10.0, 0.0}, {20.0, 10.0} }
    };
    PathsD solution = InflatePaths(subject, 2, JoinType::Miter, EndType::Butt);


    SvgWriter svg;
    SvgAddSolution(svg, solution, fill_rule, true);
    SvgAddOpenSubject(svg, subject);
    SvgSaveToFile(svg, output_path, 1024, 1024, 200);

    return EXIT_SUCCESS;
}