# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 2b3c358928adb2aa15a6c326c6098e1e6c5705e1
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
