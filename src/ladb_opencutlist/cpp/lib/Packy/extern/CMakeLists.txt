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
        GIT_TAG 4b8b6dcf360d61792bcc4fd7f4ef77d798393c43
#        SOURCE_DIR "${PROJECT_SOURCE_DIR}/../fontanf-packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
