# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 2418046fc6d9fb1e5d06f03acaf419ee2241f490
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
