# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 535f74ce5815ce5ce3525316fec8d581fcd972f9
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
