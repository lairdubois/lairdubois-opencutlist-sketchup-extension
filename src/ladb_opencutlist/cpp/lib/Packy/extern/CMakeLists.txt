# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG 5bb0504aaa46d8fe37b2eb11e0d5b544e067d532
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
