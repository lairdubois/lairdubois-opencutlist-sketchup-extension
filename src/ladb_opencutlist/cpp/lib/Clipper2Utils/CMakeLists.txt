# -------------------------------------------------------------------
#                       Clipper2Utils
# -------------------------------------------------------------------

# Library headers
set(LIBRARY_HEADERS
        include/clipper.svg.h
        include/clipper.svg.utils.h
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
set(LIBRARY_SOURCES
        src/clipper.svg.cpp
)
source_group("Sources" FILES ${LIBRARY_SOURCES})

add_library(Clipper2Utils ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

target_include_directories(Clipper2Utils PUBLIC include)
target_link_libraries(Clipper2Utils PUBLIC Clipper2)

