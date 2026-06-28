#pragma once

/**
 * SkpHeaderReader.h
 *
 * Utility class for detecting the SketchUp version of a .skp file.
 * Handles both formats:
 *   - Legacy (MFC / SketchUp ≤ 2020): proprietary MFC binary
 *     Header structure:
 *       FF FE FF 0E  → UTF-16 LE BOM + MFC prefix (length = 14)
 *       "SketchUp Model" in UTF-16 LE (28 bytes)
 *       FF FE FF 0A  → MFC prefix for next field (length = 10)
 *       "{26.2.242}" in UTF-16 LE  ← SketchUp version
 *       "VFF"        → internal container magic
 *
 *   - New (ZIP / SketchUp ≥ 2021): ZIP container with model.json
 *
 * Usage:
 *   SkpHeaderReader reader("my_file.skp");
 *   if (reader.parse()) {
 *       std::cout << reader.version_string() << "\n"; // "26.2.242"
 *       std::cout << reader.version_label()  << "\n"; // "SketchUp 2026"
 *   }
 */

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
        // Detected SKP file format
        enum class Format {
            Unknown,
            Legacy,  // MFC binary (SketchUp ≤ 2020)
            Zip,     // ZIP container (SketchUp ≥ 2021)
        };

        // Result of a parse attempt
        struct Result {
            bool        success        = false;
            Format      format         = Format::Unknown;
            std::string version_string;   // e.g. "26.2.242" (MFC) or "21" (ZIP)
            std::string label;            // e.g. "SketchUp 2026"
            uint64_t    version_number = 0; // e.g. 2600224200  (matches Sketchup.version_number)
            std::string error_message;
        };

        explicit SkpHeaderReader(std::string filepath);

        // Runs detection. Returns false if the file is unreadable or unrecognized.
        bool parse();

        // Reads a .skp file named by j_input["filepath"] and returns a JSON result
        // with "version_label", "version_string", "version_number" on success or "error" on failure.
        static json run(const std::string& filepath);
        static json run(std::istream& is);

        // Accessors (valid only after a successful parse())
        bool        is_valid()        const { return result_.success; }
        Format      format()          const { return result_.format; }
        std::string version_string()  const { return result_.version_string; }
        std::string version_label()   const { return result_.label; }
        uint64_t    version_number()  const { return result_.version_number; }
        std::string error_message()   const { return result_.error_message; }
        const Result& result()        const { return result_; }

        // Hexadecimal + ASCII dump of the first N bytes (xxd style)
        std::string hex_dump(size_t maxBytes = 64) const;

        // Mapping from major version number to SketchUp label
        static const std::map<uint32_t, std::string>& version_map();

    private:
        static constexpr size_t kMagicLen   = 14;         // "SketchUp Model"
        static constexpr size_t kHeaderSize = 128;        // bytes read upfront
        static constexpr size_t kZipChunk  = 256 * 1024;

        static const char    kLegacyMagic[kMagicLen];
        static const uint8_t kZipMagic[4];

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
        static uint64_t compute_version_number(const std::string& version_string);

        bool parse_legacy();
        bool parse_zip();
    };

}