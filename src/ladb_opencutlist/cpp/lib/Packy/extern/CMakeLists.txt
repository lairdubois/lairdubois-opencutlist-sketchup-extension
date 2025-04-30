# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 418c7433d6e97f71d989cb7eab1baec12787bc7b
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
