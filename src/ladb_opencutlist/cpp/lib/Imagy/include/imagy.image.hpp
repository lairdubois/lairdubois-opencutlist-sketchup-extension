#ifndef IMAGY_IMAGE_H
#define IMAGY_IMAGE_H

#include <cstddef>
#include <cstdint>

namespace Imagy {

    enum ImageType {
        PNG, JPG
    };

    struct Image {

        Image();

        ~Image();

        uint8_t* data;
        size_t size;
        int width;
        int height;
        int channels;

        void clear();

        bool load(
                const char* filename
        );
        bool write(
                const char* filename
        ) const;

        bool is_empty() const;

        bool flip(
                bool horizontal = true
        );
        bool rotate(
                int angle
        );

        static ImageType get_file_type(
                const char* filename
        );

    };

}

#endif // IMAGY_IMAGE_H
