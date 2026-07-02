#pragma once

#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>
#include <sstream>

#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace Skpy {

    class SkpHeaderReader {
    public:
        // Result of a parse attempt
        struct Result {
            uint32_t    version_major  = 0; // e.g. 26
            uint64_t    version_number = 0; // e.g. 2620000242 (matches Sketchup.version_number)
            std::string version_string;     // e.g. "26.2.242"
            std::string version_label;      // e.g. "SketchUp 2026"
            std::string error_message;
        };

        explicit SkpHeaderReader(std::string filepath);

        // Runs detection. Returns false if the file is unreadable or unrecognized.
        bool parse();

        // Parse the JSON input (from a file path or a stream) and read the .skp file
        // whose path is given by the "filepath" key.
        // On success: { "version_major": 26, "version_number": 2620000242, "version_string": "26.2.242", "version_label": "SketchUp 2026" }
        // On failure: { "error": "<message>" }
        static json run(const std::string& filepath);
        static json run(std::istream& is);

        // Accessors (valid only after a successful parse())
        uint32_t    version_major()   const { return result_.version_major; }
        uint64_t    version_number()  const { return result_.version_number; }
        std::string version_string()  const { return result_.version_string; }
        std::string version_label()   const { return result_.version_label; }
        std::string error_message()   const { return result_.error_message; }
        const Result& result()        const { return result_; }

        // Hexadecimal + ASCII dump of the first N bytes (xxd style)
        std::string hex_dump(size_t maxBytes = 64) const;

        // Mapping from major version number to SketchUp label
        static const std::map<uint32_t, std::string>& version_map();

    private:
        static constexpr size_t kMagicLen   = 14;         // "SketchUp Model"
        static constexpr size_t kHeaderSize = 128;        // bytes read upfront

        static const char kLegacyMagic[kMagicLen];

        std::string          filepath_;
        std::vector<uint8_t> raw_header_;
        Result               result_;

        // Reads an MFC UTF-16 LE string at the given offset.
        // MFC format: [FF FE FF <len8>] followed by <len> UTF-16 LE characters.
        // Returns the ASCII string and advances offset past the string.
        static std::optional<std::string> read_mfc_utf16_string(
            const std::vector<uint8_t>& buf,
            size_t& offset
        );

        // Resolves the SketchUp label from the major version number
        static std::string resolve_label(uint32_t major);

        // Computes the version number matching Sketchup.version_number:
        //   major < 16:  major * 1_000_000   + minor * 1_000  + build
        //   major >= 16: major * 100_000_000 + minor * 10_000_000 + build
        // Returns std::nullopt if any component is not a valid number.
        static std::optional<uint64_t> compute_version_number(const std::string& version_string);
    };

}