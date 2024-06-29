# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 9a933b9e5646f3b2c4ca8daf0dd952eec457af90
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
