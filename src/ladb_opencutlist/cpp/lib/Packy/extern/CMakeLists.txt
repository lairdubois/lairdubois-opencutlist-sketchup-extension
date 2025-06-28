# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

if(OCL_BUILD_DEBUG_EXECUTABLES)

  # Fetch boost.
  set(BOOST_INCLUDE_LIBRARIES thread filesystem system program_options dynamic_bitset)
  set(BOOST_ENABLE_CMAKE ON)
  FetchContent_Declare(
          Boost
          URL https://github.com/boostorg/boost/releases/download/boost-1.84.0/boost-1.84.0.tar.xz
          EXCLUDE_FROM_ALL)
  FetchContent_MakeAvailable(Boost)

endif()

set(COLUMNGENERATIONSOLVER_BUILD_TEST OFF)
set(COLUMNGENERATIONSOLVER_BUILD_EXAMPLES OFF)
set(COLUMNGENERATIONSOLVER_USE_CLP OFF)
set(COLUMNGENERATIONSOLVER_USE_HIGHS ON)

set(KNAPSACKSOLVER_BUILD_MAIN OFF)
set(KNAPSACKSOLVER_BUILD_TEST OFF)

set(OPTIMIZATIONTOOLS_BUILD_TEST OFF)

set(ORPROBLEMS_BUILD_TEST OFF)

set(SHAPE_BUILD_TEST OFF)

set(TRAVELINGSALESMANSOLVER_BUILD_MAIN OFF)
set(TRAVELINGSALESMANSOLVER_BUILD_TEST OFF)

set(TREESEARCHSOLVER_BUILD_TEST OFF)
set(TREESEARCHSOLVER_BUILD_EXAMPLES OFF)

set(PACKINGSOLVER_BUILD_MAIN OFF)
set(PACKINGSOLVER_BUILD_TEST OFF)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 33a9751b1a1ec91c111521e387fec492f7acfa54
#        SOURCE_DIR "${PROJECT_SOURCE_DIR}/../fontanf-packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
