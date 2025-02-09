# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 3075eb87260cba710dd414fb86deb25720be7814
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
