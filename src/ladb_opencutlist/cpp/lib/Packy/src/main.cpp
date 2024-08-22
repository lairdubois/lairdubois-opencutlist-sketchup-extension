#include <iostream>
#include <future>
#include <thread>
#include <chrono>

#include "packy.hpp"
#include "optimizer_builder.hpp"

using namespace Packy;
using namespace nlohmann;

std::shared_future<json> future_;

void optimize_async() {
  future_ = std::async(std::launch::async, []{
    json j_ouput;

    try {

      OptimizerBuilder optimizer_builder;
      Optimizer& optimizer = (*optimizer_builder.build(std::string("input.json")));

      j_ouput = optimizer.optimize();

    } catch(const std::exception& e) {
      j_ouput["error"] = "\033[1;31mError: " + std::string(e.what()) + "\033[0m";
    } catch( ... ) {
      j_ouput["error"] = "\033[1;31mUnknow Error\033[0m";
    }

    return std::move(j_ouput);
  }).share();
}

int main() {

  std::cout << "---------------------------------" << std::endl;
  std::cout << "             PACKY" << std::endl;
  std::cout << "---------------------------------" << std::endl;

  optimize_async();

  std::future_status status;
  while (true) {

    status = future_.wait_for(std::chrono::milliseconds(0));
    if (status == std::future_status::ready) {

      std::cout << "###################################" << std::endl;
      std::cout << future_.get().dump(1, ' ') << std::endl;
      std::cout << "###################################" << std::endl;

      break;
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    std::cout << "." << std::flush;

  }

  std::cout << "Done." << std::endl;

  return 0;
}
