# -------------------------------------------------------------------
#                             Nesty

if(WIN32)
  add_compile_definitions(LIBNESTY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/nesty.h
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/nesty.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/nesty.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Nesty SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Nesty
          BASE_NAME Nesty
          EXPORT_MACRO_NAME Nesty_EXPORT
          EXPORT_FILE_NAME Nesty_Export.h
          STATIC_DEFINE Nesty_BUILT_AS_STATIC
  )
endif()

target_include_directories(Nesty PUBLIC include)
target_link_libraries(Nesty PRIVATE Clipper2Wrapper)
target_compile_features(Nesty PRIVATE cxx_std_17)

install(TARGETS Nesty LIBRARY DESTINATION lib)