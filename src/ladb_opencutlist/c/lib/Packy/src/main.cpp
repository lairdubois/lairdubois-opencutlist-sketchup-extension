#include "iostream"

#include "packy.hpp"

double* GenerateTriangle(double *cpaths, double x, double y) {

  cpaths[0] = 12;   // Array length
  cpaths[1] = 1;    // 1 path

  cpaths[2] = 3;    // 3 coords
  cpaths[3] = 0;

  cpaths[4] = 0;    // X1
  cpaths[5] = 0;    // Y1

  cpaths[6] = x;    // X2
  cpaths[7] = 0;    // Y2

  cpaths[8] = x;    // X3
  cpaths[9] = y;    // Y3

  return cpaths;
}

int main() {

  std::cout << "Hello" << std::endl;
  std::cout << c_version() << std::endl;

  c_append_bin_def(0, 50, 1000, 1000, 1);

  double cpaths[12];

  c_append_item_def(0, 1, 1, GenerateTriangle(cpaths, 100, 100));

  std::string objective = "bin-packing";

  std::cout << c_execute_irregular(objective.data(), 0, 0, 3) << std::endl;

  return 0;
}
