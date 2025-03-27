# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 31d692757ec96d1d57e19f8ba6cee38bd15942c7
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
