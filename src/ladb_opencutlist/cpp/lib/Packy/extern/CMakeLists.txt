# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG b788bc1c29c19732014c51b6df2155325d862430
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
