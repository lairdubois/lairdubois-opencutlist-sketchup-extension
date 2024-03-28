#ifndef IMAGY_IMAGE_H
#define IMAGY_IMAGE_H

#include <cstddef>
#include <cstdint>

enum ImageType {
    PNG, JPG
};

enum FlipType {
    HORIZONTAL, VERTICAL
};

enum RotateType {
    LEFT, RIGHT
};

struct Image {

    uint8_t* data = nullptr;
    size_t size = 0;
    int width{};
    int height{};
    int channels{};

    Image();
    ~Image();

    void clear();

    bool load(const char* filename);
    bool write(const char* filename) const;

    bool is_empty() const;

    Image& flip(FlipType type);
    Image& rotate(RotateType type, int times = 1);

    static ImageType get_file_type(const char* filename);

};

#endif // IMAGY_IMAGE_H
