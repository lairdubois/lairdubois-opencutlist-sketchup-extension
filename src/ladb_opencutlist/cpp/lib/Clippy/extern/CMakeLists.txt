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
