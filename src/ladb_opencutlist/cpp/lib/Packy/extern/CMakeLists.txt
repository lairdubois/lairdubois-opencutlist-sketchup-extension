# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 7d7213e09c5ca2afbc1e5c58c0881f48beccc99a
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
