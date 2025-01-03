# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG ac336aaf87f59fe33fc750e318d816d2e5ec0b6a
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
