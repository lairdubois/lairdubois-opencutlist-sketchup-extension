#include "iostream"

#include "packy.hpp"

int64_t* GenerateTriangle(int64_t *cpaths, int64_t x, int64_t y) {

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

int64_t ToInt64(int v) {
  return (int64_t)(v * 1e8);
}

int main() {

  std::cout << "Hello" << std::endl;
  std::cout << c_version() << std::endl;

  c_append_bin_def(0, 10, ToInt64(1000), ToInt64(1000), 1);

  int64_t cpaths[12];

  c_append_shape_def(0, 6, GenerateTriangle(cpaths, ToInt64(100), ToInt64(100)));
  c_append_shape_def(1, 12, GenerateTriangle(cpaths, ToInt64(200), ToInt64(100)));
  c_append_shape_def(2, 24, GenerateTriangle(cpaths, ToInt64(300), ToInt64(100)));

  std::cout << c_execute_nesting(0, 0, 0) << std::endl;

  return 0;
}
