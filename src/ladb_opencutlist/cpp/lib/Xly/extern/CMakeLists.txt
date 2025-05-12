# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch nlohmann/json.
FetchContent_Declare(
        json
        URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz)
FetchContent_MakeAvailable(json)

# Fetch lairdubois/jmcnamara-libxlsxwriter.
FetchContent_Declare(
        libxlsxwriter
        GIT_REPOSITORY https://github.com/lairdubois/jmcnamara-libxlsxwriter.git
        GIT_TAG 21c11a2052162b24c121b766e4373b081ea07ff6
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(libxlsxwriter)
