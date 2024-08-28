# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        #GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG 9ad09f2e519f7516104c494e26a3b966d35e9c14
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
