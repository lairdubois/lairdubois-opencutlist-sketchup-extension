# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 0921b0407973884d1829078fe1ddcdab6021963f
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
