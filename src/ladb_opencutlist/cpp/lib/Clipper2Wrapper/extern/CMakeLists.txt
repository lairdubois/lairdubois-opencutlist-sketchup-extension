# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch lairdubois/angusjohnson-clipper2.
FetchContent_Declare(
        clipper2
        GIT_REPOSITORY https://github.com/lairdubois/angusjohnson-clipper2.git
        GIT_TAG ed98928c66707988d4eb2c49a31c41380a08931c
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(clipper2)