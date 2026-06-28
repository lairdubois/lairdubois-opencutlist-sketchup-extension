#include "skpy.hpp"
#include "skp_header_reader.hpp"

using namespace Skpy;

#ifdef __cplusplus
extern "C" {
#endif

static std::string str_output_;

DLL_EXPORTS char* c_get_skp_version_info(const char* s_input) {
    json j_output;
    try {

        std::stringstream is;
        is << s_input;

        j_output = SkpHeaderReader::run(is);

    } catch (const std::exception& e) {
        j_output = json{
            { "error", std::string(e.what()) }
        };
    } catch (...) {
        j_output = json{
            { "error", "Unknown error" }
        };
    }
    str_output_ = j_output.dump();
    return const_cast<char*>(str_output_.c_str());
}

DLL_EXPORTS char* c_version() {
    return const_cast<char*>(SKPY_VERSION);
}

#ifdef __cplusplus
}
#endif