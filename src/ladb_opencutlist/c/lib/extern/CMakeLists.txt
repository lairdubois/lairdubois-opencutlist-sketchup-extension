# Enable FetchContent.
include(FetchContent)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG 5f86e3a15cc543ab2d1b1b13039cfe414e1e235a
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)