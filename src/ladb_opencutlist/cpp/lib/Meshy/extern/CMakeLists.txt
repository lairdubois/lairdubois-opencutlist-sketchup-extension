# Enable FetchContent.
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
        URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz)
FetchContent_MakeAvailable(json)

# Fetch elalish/manifold.
set(MANIFOLD_PYBIND         OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CBIND          OFF CACHE BOOL "" FORCE)
set(MANIFOLD_TEST           OFF CACHE BOOL "" FORCE)
set(MANIFOLD_EXPORT         OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CROSS_SECTION  OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
        manifold
        GIT_REPOSITORY https://github.com/elalish/manifold.git
        GIT_TAG        v3.5.2
        GIT_SHALLOW    TRUE
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(manifold)
