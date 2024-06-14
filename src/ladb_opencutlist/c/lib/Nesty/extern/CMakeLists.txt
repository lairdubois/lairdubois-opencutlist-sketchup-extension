# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/fontanf/packingsolver.git
        GIT_TAG 87c9f376e436e013851bbbb52a764163fbbff679
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
