#include "skp_header_reader.hpp"

#include <cctype>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>

using namespace Skpy;

// ---------------------------------------------------------------------------
// run()
// ---------------------------------------------------------------------------

json SkpHeaderReader::run(
        const std::string& filepath
) {

    std::ifstream ifs(filepath);
    if (!ifs.good()) {
        throw std::runtime_error("Unable to open file path \"" + filepath + "\".");
    }

    return run(ifs);
}

json SkpHeaderReader::run(
        std::istream& is
) {

    json j;
    is >> j;

    if (j.contains("filepath")) {

        std::string filepath = j.value("filepath", "");
        SkpHeaderReader reader(filepath);
        if (reader.parse()) {
            return json{
                    { "version_string", reader.version_string() },
                    { "version_major",  reader.version_major()  },
                    { "version_number", reader.version_number() },
                    { "version_label",  reader.version_label()  },
                };
        }
        return json{
                { "error", reader.error_message() }
        };

    } else {
        throw std::invalid_argument("Missing \"filepath\" parameter.");
    }
}

// ---------------------------------------------------------------------------
// compute_version_number()
// ---------------------------------------------------------------------------

std::optional<uint64_t> SkpHeaderReader::compute_version_number(const std::string& version_string) {
    uint64_t major = 0, minor = 0, build = 0;
    std::istringstream ss(version_string);
    std::string token;
    auto to_number = [](const std::string& s) -> std::optional<uint64_t> {
        if (s.empty() || s.find_first_not_of("0123456789") != std::string::npos) return std::nullopt;
        try {
            return std::stoull(s);
        } catch (...) {
            return std::nullopt;   // out of range
        }
    };
    if (std::getline(ss, token, '.')) {
        auto v = to_number(token);
        if (!v) return std::nullopt;
        major = *v;
    }
    if (std::getline(ss, token, '.')) {
        auto v = to_number(token);
        if (!v) return std::nullopt;
        minor = *v;
    }
    if (std::getline(ss, token, '.')) {
        auto v = to_number(token);
        if (!v) return std::nullopt;
        build = *v;
    }
    if (major < 16) {
        return major * 1000000ULL + minor * 1000ULL + build;
    }
    return major * 100000000ULL + minor * 10000000ULL + build;
}

// ---------------------------------------------------------------------------
// Static constants
// ---------------------------------------------------------------------------

const char SkpHeaderReader::kLegacyMagic[SkpHeaderReader::kMagicLen] = {
    'S','k','e','t','c','h','U','p',' ','M','o','d','e','l'
};

// ---------------------------------------------------------------------------
// Major version → SketchUp label mapping
// ---------------------------------------------------------------------------

const std::map<uint32_t, std::string>& SkpHeaderReader::version_map() {
    static const std::map<uint32_t, std::string> kMap = {
        { 6, "SketchUp 6 / Google SketchUp 6" },
        { 7, "Google SketchUp 7"              },
        { 8, "Google SketchUp 8"              },
    };
    return kMap;
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

SkpHeaderReader::SkpHeaderReader(std::string filepath)
    : filepath_(std::move(filepath))
{}

// ---------------------------------------------------------------------------
// Read an MFC UTF-16 LE string
//
// Expected layout at the current offset:
//   FF FE FF <len8>   (4-byte MFC prefix)
//   then <len8> UTF-16 LE characters (2 bytes each)
//
// Only ASCII characters are decoded (high byte == 0x00).
// ---------------------------------------------------------------------------

std::optional<std::string> SkpHeaderReader::read_mfc_utf16_string(
        const std::vector<uint8_t>& buf,
        size_t& offset
) {

    // MFC prefix: FF FE FF <length>
    if (offset + 4 > buf.size()) return std::nullopt;
    if (buf[offset]     != 0xFF ||
        buf[offset + 1] != 0xFE ||
        buf[offset + 2] != 0xFF) {
        return std::nullopt;
    }

    uint8_t len = buf[offset + 3];   // number of UTF-16 characters
    offset += 4;

    if (offset + len * 2u > buf.size()) return std::nullopt;

    std::string result;
    result.reserve(len);
    for (uint8_t i = 0; i < len; ++i) {
        uint8_t lo = buf[offset + i * 2];
        uint8_t hi = buf[offset + i * 2 + 1];
        // Only accept ASCII characters (high byte == 0)
        result += (hi == 0x00) ? static_cast<char>(lo) : '?';
    }
    offset += len * 2u;

    return result;
}

// ---------------------------------------------------------------------------
// Resolve label from major version number
// ---------------------------------------------------------------------------

std::string SkpHeaderReader::resolve_label(uint32_t major) {
    auto it = version_map().find(major);
    if (it != version_map().end()) return it->second;
    if (major >= 13) return "SketchUp " + std::to_string(2000 + major);
    return "SketchUp " + std::to_string(major);
}

// ---------------------------------------------------------------------------
// parse()
// ---------------------------------------------------------------------------

bool SkpHeaderReader::parse() {
    result_ = Result{};

    std::ifstream f(filepath_, std::ios::binary);
    if (!f) {
        result_.error_message = "Failed to open : " + filepath_;
        return false;
    }

    raw_header_.assign(kHeaderSize, 0);
    f.read(reinterpret_cast<char*>(raw_header_.data()), kHeaderSize);
    raw_header_.resize(static_cast<size_t>(f.gcount()));

    if (raw_header_.size() < 4) {
        result_.error_message = "File is too short.";
        return false;
    }

    // Expected header layout:
    //   [FF FE FF 0E] "SketchUp Model" UTF-16 LE   (4 + 28 = 32 bytes)
    //   [FF FE FF 0A] "{26.2.242}"     UTF-16 LE   (4 + 20 = 24 bytes)
    //   "VFF" ...

    size_t offset = 0;

    // 1. Read the first field: must be "SketchUp Model"
    auto field1 = read_mfc_utf16_string(raw_header_, offset);
    if (!field1) {
        result_.error_message = "Prefix not found.";
        return false;
    }
    if (*field1 != std::string(kLegacyMagic, kMagicLen)) {
        result_.error_message = "Magic 'SketchUp Model' not found. Read : '" + *field1 + "'";
        return false;
    }

    // 2. Read the second field: version in the form "{M.m.p}"
    auto field2 = read_mfc_utf16_string(raw_header_, offset);
    if (!field2 || field2->size() < 3) {
        result_.error_message = "Version field not found.";
        return false;
    }

    // Strip braces: "{26.2.242}" → "26.2.242"
    std::string version_string = *field2;
    if (version_string.front() == '{') version_string.erase(0, 1);
    if (version_string.back()  == '}') version_string.pop_back();

    // Extract the major version (before the first '.')
    uint32_t major = 0;
    try {
        major = static_cast<uint32_t>(std::stoul(version_string));
    } catch (...) {
        result_.error_message = "Major version can't be parsed : " + version_string;
        return false;
    }

    auto version_number = compute_version_number(version_string);
    if (!version_number) {
        result_.error_message = "Version can't be parsed : " + version_string;
        return false;
    }

    result_.version_major   = major;
    result_.version_number  = *version_number;
    result_.version_string  = version_string;
    result_.version_label   = resolve_label(major);
    return true;
}

// ---------------------------------------------------------------------------
// hex_dump() — xxd style
// ---------------------------------------------------------------------------

std::string SkpHeaderReader::hex_dump(size_t maxBytes) const {
    std::ostringstream oss;
    size_t limit = std::min(raw_header_.size(), maxBytes);
    oss << std::hex << std::uppercase << std::setfill('0');

    for (size_t i = 0; i < limit; i += 16) {
        oss << std::setw(8) << i << "  ";

        for (size_t j = i; j < std::min(i + 16, limit); ++j)
            oss << std::setw(2) << static_cast<unsigned>(raw_header_[j]) << ' ';

        for (size_t j = limit; j < i + 16; ++j) oss << "   ";

        oss << " |";
        for (size_t j = i; j < std::min(i + 16, limit); ++j) {
            char c = static_cast<char>(raw_header_[j]);
            oss << (std::isprint(static_cast<unsigned char>(c)) ? c : '.');
        }
        oss << "|\n";
    }
    return oss.str();
}