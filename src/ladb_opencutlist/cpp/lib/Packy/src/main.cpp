#include <iostream>
#include <thread>

#include "packy.hpp"
#include "optimizer_builder.hpp"

using namespace Packy;
using namespace nlohmann;

void optimize() {

  try {

    OptimizerBuilder optimizer_builder;
    Optimizer& optimizer = optimizer_builder.build(std::string("input.json"));

    json ouput = optimizer.optimize();

    std::cout << "###################################" << std::endl;
    std::cout << ouput.dump(1, ' ') << std::endl;
    std::cout << "###################################" << std::endl;

  } catch(const std::exception &e) {
    std::cerr << "\033[1;31mError: " << (std::string)e.what() << "\033[0m" << std::endl;
  } catch( ... ) {
    std::cerr << "\033[1;31mUnknow Error\033[0m" << std::endl;
  }

}

int main() {

  std::cout << "-----------------------------------" << std::endl;
  std::cout << "              PACKY" << std::endl;
  std::cout << "-----------------------------------" << std::endl;

  std::thread t(optimize);
  t.join();

  return 0;
}
