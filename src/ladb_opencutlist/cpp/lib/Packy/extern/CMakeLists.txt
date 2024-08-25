# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        #GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG 305469184e8d2277c5722b85bddd60e9ec27441b
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
