#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION

#define STBI_NO_BMP
#define STBI_NO_PSD
#define STBI_NO_TGA
#define STBI_NO_GIF
#define STBI_NO_HDR
#define STBI_NO_PIC
#define STBI_NO_PNM

#include "stb_image.hpp"
#include "stb_image_write.hpp"

#include "imagy.image.hpp"

#include <utility>

namespace Imagy {

    Image::Image() :
            data(nullptr),
            width(0),
            height(0),
            channels(0),
            size(0) {}

    Image::~Image() {
        if (!is_empty()) clear();
    }

    // -- Cleaner

    void Image::clear() {
        if (data != nullptr) stbi_image_free(data);
        data = nullptr;
        width = 0;
        height = 0;
        channels = 0;
        size = 0;
    }

    // -- Load / Write

    bool Image::load(
            const char* filename
    ) {
        if (!is_empty()) clear();
        data = stbi_load(filename, &width, &height, &channels, 0);
        size = width * height * channels;
        return !is_empty();
    }

    bool Image::write(
            const char* filename
    ) const {
        if (is_empty()) return false;

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

    // -- State

    bool Image::is_empty() const {
        return data == nullptr;
    }

    // -- Manipulations

    inline int fn_data_pos(
            int x,
            int y,
            Image& image
    ) { return (x + y * image.width) * image.channels; }

    inline int fn_data_pos_rot_90(
            int x,
            int y,
            Image& image
    ) {
        return (x * image.height + (image.height - 1 - y)) * image.channels;
    }

    inline int fn_data_pos_rot_180(
            int x,
            int y,
            Image& image
    ) {
        return ((image.width - 1 - x) + (image.height - 1 - y) * image.width) * image.channels;
    }

    inline int fn_data_pos_rot_270(
            int x,
            int y,
            Image& image
    ) {
        return ((image.width - 1 - x) * image.height + y) * image.channels;
    }

    inline int fn_data_pos_flip_h(
            int x,
            int y,
            Image& image
    ) {
        return ((image.width - 1 - x) + y * image.width) * image.channels;
    }

    inline int fn_data_pos_flip_v(
            int x,
            int y,
            Image& image
    ) {
        return (x + (image.height - 1 - y) * image.width) * image.channels;
    }

    inline void fn_data_swap(
            int pos1,
            int pos2,
            Image& image
    ) {

        uint8_t tmp[4];
        uint8_t* px1 = &image.data[pos1];
        uint8_t* px2 = &image.data[pos2];

        memcpy(tmp, px1, image.channels);
        memcpy(px1, px2, image.channels);
        memcpy(px2, tmp, image.channels);

    }

    /*
     * Flip the image pixels.
     * Horizontally if 'horizontal' is true, vertically otherwise.
     */
    bool Image::flip(
            bool horizontal
    ) {
        if (is_empty()) return false;

        if (horizontal) {

            int half_width = width / 2;
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < half_width; ++x) {
                    fn_data_swap(fn_data_pos(x, y, *this), fn_data_pos_flip_h(x, y, *this), *this);
                }
            }

        } else {

            int half_height = height / 2;
            for (int x = 0; x < width; ++x) {
                for (int y = 0; y < half_height; ++y) {
                    fn_data_swap(fn_data_pos(x, y, *this), fn_data_pos_flip_v(x, y, *this), *this);
                }
            }

        }

        return true;
    }

    /*
     * Rotate the image pixels by the given 'angle'.
     * Angle value can be 0, 90, 180, 270.
     */
    bool Image::rotate(
            int angle
    ) {
        if (is_empty()) return false;

        angle = ((angle / 90) * 90) % 360;
        if (angle == 0) return false;

        if (angle == 180) {

            int half_width = width / 2;
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < half_width; ++x) {
                    fn_data_swap(fn_data_pos(x, y, *this), fn_data_pos_rot_180(x, y, *this), *this);
                }
            }

        } else {

            int (* fn_data_pos_rot)(int, int, Image&);
            if (angle == 90) {
                fn_data_pos_rot = &fn_data_pos_rot_90;
            } else if (angle == 270) {
                fn_data_pos_rot = &fn_data_pos_rot_270;
            }

            auto* tmp_data = new uint8_t[size];
            uint8_t* px_s;
            uint8_t* px_d;

            for (int x = 0; x < width; ++x) {
                for (int y = 0; y < height; ++y) {

                    px_s = &data[fn_data_pos(x, y, *this)];
                    px_d = &tmp_data[fn_data_pos_rot(x, y, *this)];

                    memcpy(px_d, px_s, channels);

                }
            }

            memcpy(data, tmp_data, size);
            std::swap(width, height);

        }

        return true;
    }

    // -- Utils

    ImageType Image::get_file_type(
            const char* filename
    ) {
        const char* ext = strrchr(filename, '.');
        if (ext != nullptr) {
            if (strcmp(ext, ".png") == 0) {
                return PNG;
            } else if (strcmp(ext, ".jpg") == 0) {
                return JPG;
            }
        }
        return PNG;
    }

}

