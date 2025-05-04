# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/fontanf-packingsolver.
FetchContent_Declare(
        packingsolver
        GIT_REPOSITORY https://github.com/lairdubois/fontanf-packingsolver.git
        GIT_TAG c481de16842ff0ee0942dfaff13ac525aa3c79b4
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(packingsolver)
