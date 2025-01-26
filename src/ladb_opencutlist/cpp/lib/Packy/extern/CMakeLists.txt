# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG bb739ea605c12d17d8fbf43371f6af108799c5de
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
