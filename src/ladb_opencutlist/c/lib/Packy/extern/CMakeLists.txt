# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG b78bd5cc20c35c78495daa94bcd9f6034bb5bae6
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
