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

Image::Image(int width, int height, int channels) : width(width), height(height), channels(channels) {
  size = width * height * channels;
  data = new uint8_t[size];
}

Image::Image(const Image &img) : Image(img.width, img.height, img.channels) {
  memcpy(data, img.data, size);
}

Image::~Image() {
  stbi_image_free(data);
}

bool Image::read(const char *filename, int channel_force) {
  data = stbi_load(filename, &width, &height, &channels, channel_force);
  channels = channel_force == 0 ? channels : channel_force;
  size = width * height * channels;
  return data != nullptr;
}

bool Image::write(const char *filename) {
  ImageType type = get_file_type(filename);
  int success;
  switch (type) {
    case PNG:
      success = stbi_write_png(filename, width, height, channels, data, width * channels);
      break;
    case JPG:
      success = stbi_write_jpg(filename, width, height, channels, data, 80);
      break;
  }
  return success != 0;
}

void Image::clear() {
  stbi_image_free(data);
  width = 0;
  height = 0;
  channels = 3;
  size = width * height * channels;
  data = new uint8_t[size];
}

Image &Image::flip_x() {
  uint8_t tmp[4];
  uint8_t *px1;
  uint8_t *px2;
  for (int y = 0; y < height; ++y) {
    for (int x = 0; x < width / 2; ++x) {

      px1 = &data[(x + y * width) * channels];
      px2 = &data[((width - 1 - x) + y * width) * channels];

      memcpy(tmp, px1, channels);
      memcpy(px1, px2, channels);
      memcpy(px2, tmp, channels);

    }
  }
  return *this;
}

Image &Image::flip_y() {
  uint8_t tmp[4];
  uint8_t *px1;
  uint8_t *px2;
  for (int x = 0; x < width; ++x) {
    for (int y = 0; y < height / 2; ++y) {

      px1 = &data[(x + y * width) * channels];
      px2 = &data[(x + (height - 1 - y) * width) * channels];

      memcpy(tmp, px1, channels);
      memcpy(px1, px2, channels);
      memcpy(px2, tmp, channels);

    }
  }
  return *this;
}

Image &Image::rotate_left() {
  uint8_t tmp_data[size];
  uint8_t *px_s;
  uint8_t *px_d;
  for (int x = 0; x < width; ++x) {
    for (int y = 0; y < height; ++y) {

      px_s = &data[(x + y * width) * channels];
      px_d = &tmp_data[((width - 1 - x) * height + y) * channels];

      memcpy(px_d, px_s, channels);

    }
  }
  memcpy(data, &tmp_data, size);
  int tmp_width = width;
  width = height;
  height = tmp_width;
  return *this;
}

Image &Image::rotate_right() {
  uint8_t tmp_data[size];
  uint8_t *px_s;
  uint8_t *px_d;
  for (int x = 0; x < width; ++x) {
    for (int y = 0; y < height; ++y) {

      px_s = &data[(x + y * width) * channels];
      px_d = &tmp_data[(x * height + (height - 1 - y)) * channels];

      memcpy(px_d, px_s, channels);

    }
  }
  memcpy(data, &tmp_data, size);
  int tmp_width = width;
  width = height;
  height = tmp_width;
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
