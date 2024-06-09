#include <cstdlib>
#include "iostream"

#include "nesty.hpp"

int main() {

  std::cout << "Hello" << std::endl;
  std::cout << c_version() << std::endl;

  int64_t v = 100;
  int64_t cpaths[12];
  cpaths[0] = 12;
  cpaths[1] = 1;    // 1 path

  cpaths[2] = 4;    // 4 coords
  cpaths[3] = 0;

  cpaths[4] = 0;    // X1
  cpaths[5] = 0;    // Y1

  cpaths[6] = v;    // X2
  cpaths[7] = 0;    // Y2

  cpaths[8] = 0;    // X3
  cpaths[9] = v;    // Y3

  cpaths[10] = 0;    // X4
  cpaths[11] = 0;    // Y4

  c_append_bin_def(0, 1, 1000, 1000, 1);
  c_append_shape_def(0, 6, cpaths);

  std::cout << c_execute_nesting(0, 0, 0) << std::endl;

  return 0;
}
