# Enable FetchContent.
include(FetchContent)

Set(FETCHCONTENT_QUIET FALSE)

# Fetch kuba--/zip.
FetchContent_Declare(
        zip
        GIT_REPOSITORY https://github.com/kuba--/zip.git
        GIT_TAG d7a2252a537926cbdef8512741a322a183fcfd09
        EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(zip)
