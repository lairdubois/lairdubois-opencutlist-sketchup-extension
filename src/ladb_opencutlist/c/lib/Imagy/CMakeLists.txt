# -------------------------------------------------------------------
#                             Imagy

if(WIN32)
  add_compile_definitions(LIBIMAGY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/imagy.hpp
        include/imagy.image.hpp
        include/stb_image.hpp
        include/stb_image_write.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/imagy.cpp
          src/imagy.image.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/imagy.cpp
          src/imagy.image.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Imagy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Imagy
          BASE_NAME Imagy
          EXPORT_MACRO_NAME Imagy_EXPORT
          EXPORT_FILE_NAME Imagy_Export.h
          STATIC_DEFINE Imagy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Imagy PUBLIC include)
target_compile_features(Imagy PRIVATE cxx_std_17)

install(TARGETS Imagy RUNTIME DESTINATION lib)