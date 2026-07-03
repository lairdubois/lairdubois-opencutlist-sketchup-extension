include(FetchContent)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

Set(FETCHCONTENT_QUIET FALSE)

# Fetch boost.
if(OCL_BUILD_MAIN)
  set(BOOST_INCLUDE_LIBRARIES filesystem program_options)
  set(BOOST_ENABLE_CMAKE ON)
  FetchContent_Declare(
          Boost
          URL https://github.com/boostorg/boost/releases/download/boost-1.84.0/boost-1.84.0.tar.xz
          EXCLUDE_FROM_ALL)
  FetchContent_MakeAvailable(Boost)
endif()

# Fetch nlohmann/json.
FetchContent_Declare(
        json
        URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(json)