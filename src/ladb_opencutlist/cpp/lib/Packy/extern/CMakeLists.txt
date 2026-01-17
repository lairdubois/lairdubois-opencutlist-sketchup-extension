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

# Fetch lairdubois/fontanf-packingsolver.
set(PACKINGSOLVER_BUILD_MAIN OFF)
set(PACKINGSOLVER_BUILD_TEST OFF)
set(PACKINGSOLVER_USE_CLP OFF)
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 925cdf809e8c6e6471991b1e11bd548852d4cd7f
#        SOURCE_DIR "${PROJECT_SOURCE_DIR}/../fontanf-packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
