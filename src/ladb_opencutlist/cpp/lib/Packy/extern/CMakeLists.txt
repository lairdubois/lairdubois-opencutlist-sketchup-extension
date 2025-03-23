# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 6ea89b0edc9aec40aadb24f6b4db516124ca0130
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
