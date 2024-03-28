#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION

#define STBI_NO_BMP
#define STBI_NO_PSD
#define STBI_NO_TGA
#define STBI_NO_GIF
#define STBI_NO_HDR
#define STBI_NO_PIC
#define STBI_NO_PNM

#include "stb_image.h"
#include "stb_image_write.h"

#include "imagy.image.h"

Image::Image() {
  width = 0;
  height = 0;
  channels = 3;
  size = width * height * channels;
  data = nullptr;
}

Image::~Image() {
  if (!is_empty()) {
    clear();
  }
}

// -- Cleaner

void Image::clear() {
  width = 0;
  height = 0;
  channels = 3;
  size = width * height * channels;
  if (data != nullptr) {
    stbi_image_free(data);
  }
  data = nullptr;
}

// -- Load / Write

bool Image::load(const char *filename) {
  if (!is_empty()) {
    clear();
  }
  data = stbi_load(filename, &width, &height, &channels, 0);
  size = width * height * channels;
  return !is_empty();
}

bool Image::write(const char *filename) const {
  if (!is_empty()) {
    int success;
    switch (get_file_type(filename)) {
      case PNG:
        success = stbi_write_png(filename, width, height, channels, data, width * channels);
        break;
      case JPG:
        success = stbi_write_jpg(filename, width, height, channels, data, 90);
        break;
    }
    return success != 0;
  }
  return false;
}

// -- State

bool Image::is_empty() const {
  return data == nullptr;
}

// -- Manipulations

Image &Image::flip(FlipType type) {
  if (!is_empty()) {
    uint8_t tmp[4];
    uint8_t *px1;
    uint8_t *px2;
    for (int y = 0; y < height; ++y) {
      for (int x = 0; x < width / 2; ++x) {

        px1 = &data[(x + y * width) * channels];
        switch (type) {
          case HORIZONTAL:
            px2 = &data[((width - 1 - x) + y * width) * channels];
            break;
          case VERTICAL:
            px2 = &data[(x + (height - 1 - y) * width) * channels];
            break;
        }

        memcpy(tmp, px1, channels);
        memcpy(px1, px2, channels);
        memcpy(px2, tmp, channels);

      }
    }
  }
  return *this;
}

Image &Image::rotate(RotateType type, int times) {
  if (!is_empty()) {

    auto* tmp_data = new uint8_t[size];
    uint8_t* px_s;
    uint8_t* px_d;

    for (int t = 0 ; t < (times % 4); ++t) {

      for (int x = 0; x < width; ++x) {
        for (int y = 0; y < height; ++y) {

          px_s = &data[(x + y * width) * channels];
          switch (type) {
            case LEFT:
              px_d = &tmp_data[((width - 1 - x) * height + y) * channels];
              break;
            case RIGHT:
              px_d = &tmp_data[(x * height + (height - 1 - y)) * channels];
              break;
          }

          memcpy(px_d, px_s, channels);

        }
      }

      memcpy(data, tmp_data, size);
      int tmp_width = width;
      width = height;
      height = tmp_width;

    }

  }
  return *this;
}

ImageType Image::get_file_type(const char *filename) {
  const char *ext = strrchr(filename, '.');
  if (ext != nullptr) {
    if (strcmp(ext, ".png") == 0) {
      return PNG;
    } else if (strcmp(ext, ".jpg") == 0) {
      return JPG;
    }
  }
  return PNG;
}
