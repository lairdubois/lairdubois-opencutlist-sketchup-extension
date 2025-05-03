# -------------------------------------------------------------------
#                       Clipper2Wrapper
# -------------------------------------------------------------------

# Library headers
set(LIBRARY_HEADERS
        include/clipper2/clipper.wrapper.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
set(LIBRARY_SOURCES
        src/clipper.wrapper.cpp
)
source_group("Sources" FILES ${LIBRARY_SOURCES})

add_library(Clipper2Wrapper ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

target_include_directories(Clipper2Wrapper PUBLIC include)
target_link_libraries(Clipper2Wrapper PUBLIC Clipper2)
