# Enable FetchContent.
include(FetchContent)

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

# Fetch cutdigital/mcut.
set(MCUT_BUILD_TUTORIALS      OFF CACHE BOOL "" FORCE)
set(MCUT_BUILD_TESTS          OFF CACHE BOOL "" FORCE)
set(MCUT_BUILD_AS_SHARED_LIB  OFF CACHE BOOL "" FORCE)
add_compile_definitions(LICENSE_NOTICE_ACKNOWLEDGED)
FetchContent_Declare(
        mcut
#        GIT_REPOSITORY https://github.com/cutdigital/mcut.git
#        GIT_TAG d424aec52454c22cd9d436907f28db3595e706e1
        GIT_REPOSITORY https://github.com/lairdubois/cutdigital-mcut.git
        GIT_TAG 6743a85e32b75c79a309666b19c430d15a5e69f7
#        SOURCE_DIR "${PROJECT_SOURCE_DIR}/../cutdigital-mcut/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(mcut)

# Fetch elalish/manifold.
set(MANIFOLD_PYBIND         OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CBIND          OFF CACHE BOOL "" FORCE)
set(MANIFOLD_TEST           OFF CACHE BOOL "" FORCE)
set(MANIFOLD_EXPORT         OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CROSS_SECTION  OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
        manifold
        GIT_REPOSITORY https://github.com/elalish/manifold.git
        GIT_TAG        v3.4.1
        GIT_SHALLOW    TRUE
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(manifold)
