# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 12a617332a2068b65ff760d54899a298b76949dd
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
