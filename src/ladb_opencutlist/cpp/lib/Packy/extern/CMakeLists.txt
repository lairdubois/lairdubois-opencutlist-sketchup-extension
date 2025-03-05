# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG be6b19e196a6d625ef1699bb2483fb8b11755243
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
