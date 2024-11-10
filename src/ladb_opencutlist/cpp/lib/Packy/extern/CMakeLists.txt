# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG f2eb7abe03acdbbbf8eb7ac9c798418b5d0ce84a
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
