# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        #GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG bcfc1f6547ec0b969db116bee26a968b926d3946
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
