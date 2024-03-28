#ifndef IMAGY_IMAGE_H
#define IMAGY_IMAGE_H

#include <cstddef>
#include <cstdint>

enum ImageType {
    PNG, JPG
};

struct Image {

    uint8_t* data = nullptr;
    size_t size = 0;
    int width{};
    int height{};
    int channels{};

    Image(int width, int height, int channels = 3);
    Image(const Image& img);
    ~Image();

    bool read(const char* filename, int channel_force = 0);
    bool write(const char* filename);
    void clear();

    static ImageType get_file_type(const char* filename);

    Image& flip_x();
    Image& flip_y();

    Image& rotate_left();
    Image& rotate_right();

};

#endif // IMAGY_IMAGE_H
