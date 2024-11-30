# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 0600c9a82ccc74cf1ef592c0f3237cb1ec8f0d14
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
