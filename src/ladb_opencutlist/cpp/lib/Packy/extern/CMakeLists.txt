# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 731b7a10a4b9d87ec1d763dfb7c0ef8558e7a5cc
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
