# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG e5ed4ca362ef3835733221fda2d8a156166b47bb
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
