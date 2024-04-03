#include "iostream"

#include "nesty.h"

int main() {

  std::cout << "Hello" << std::endl;

  std::cout << c_version() << std::endl;
  std::cout << c_execute_nesting(0, 0, 0) << std::endl;

  std::cin.ignore();

  return 0;
}
