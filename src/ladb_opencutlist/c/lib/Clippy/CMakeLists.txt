# -------------------------------------------------------------------
#                             Clippy

if(WIN32)
  add_compile_definitions(LIBCLIPPY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/clippy.h
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/clippy.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/clippy.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Clippy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Clippy
          BASE_NAME Clippy
          EXPORT_MACRO_NAME Clippy_EXPORT
          EXPORT_FILE_NAME Clippy_Export.h
          STATIC_DEFINE Clippy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Clippy PUBLIC include)
target_link_libraries(Clippy PRIVATE Clipper2Wrapper)
target_compile_features(Clippy PRIVATE cxx_std_17)

install(TARGETS Clippy LIBRARY DESTINATION lib)