# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 1f687eb76af343e899853474cec2eed5766de786
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
