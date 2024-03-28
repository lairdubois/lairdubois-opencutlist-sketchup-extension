#include <imagy.h>

#ifdef __cplusplus
extern "C" {
#endif

Image image(0, 0);

DLL_EXPORTS int c_load(const char* filename) {
  return image.load(filename) ? 1 : 0;
}
DLL_EXPORTS int c_write(const char* filename) {
  return image.write(filename) ? 1 : 0;
}
DLL_EXPORTS void c_clear(void) {
  return image.clear();
}

DLL_EXPORTS int c_get_width(void) {
  return image.width;
}
DLL_EXPORTS int c_get_height(void) {
  return image.height;
}


DLL_EXPORTS void c_flip_x(void) {
  image.flip_x();
}
DLL_EXPORTS void c_flip_y(void) {
  image.flip_y();
}


DLL_EXPORTS void c_rotate_left(int times) {
  for (int t = 0 ; t < times; ++t) {
    image.rotate_left();
  }
}
DLL_EXPORTS void c_rotate_right(int times) {
  for (int t = 0 ; t < times; ++t) {
    image.rotate_right();
  }
}


DLL_EXPORTS char* c_version(void) {
  return (char *)IMAGY_VERSION;
}

#ifdef __cplusplus
}
#endif