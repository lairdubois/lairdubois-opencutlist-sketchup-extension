# Enable FetchContent.
include(FetchContent)

message(STATUS "Fetching Dependencies...")

Set(FETCHCONTENT_QUIET FALSE)

# Fetch fontanf/packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 28a845f36fa72a585d7a98a81b84b76f5006deb7
        #SOURCE_DIR "${PROJECT_SOURCE_DIR}/../packingsolver/"
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)

message(STATUS "Dependencies fetch completed")
