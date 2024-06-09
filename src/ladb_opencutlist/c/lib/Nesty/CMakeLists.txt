# -------------------------------------------------------------------
#                             Nesty

if(WIN32)
  add_compile_definitions(LIBNESTY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/nesty.hpp
        include/nesty.structs.hpp
        include/nesty.engine.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/nesty.cpp
          src/nesty.structs.cpp
          src/nesty.engine.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/nesty.cpp
          src/nesty.structs.cpp
          src/nesty.engine.cpp
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
target_link_libraries(Nesty PUBLIC PackingSolver::onedimensional)
target_link_libraries(Nesty PUBLIC PackingSolver::rectangle)
target_link_libraries(Nesty PUBLIC PackingSolver::rectangleguillotine)
target_compile_features(Nesty PRIVATE cxx_std_17)

install(TARGETS Nesty RUNTIME DESTINATION lib)

# Debug executable

add_executable(NestyMain ${LIBRARY_HEADERS} ${LIBRARY_SOURCES} src/main.cpp)
target_include_directories(NestyMain PUBLIC include)
target_link_libraries(NestyMain PRIVATE Clipper2Wrapper)
target_link_libraries(NestyMain PUBLIC PackingSolver::onedimensional)
target_link_libraries(NestyMain PUBLIC PackingSolver::rectangle)
target_link_libraries(NestyMain PUBLIC PackingSolver::rectangleguillotine)
target_compile_features(NestyMain PRIVATE cxx_std_17)

install(TARGETS NestyMain RUNTIME DESTINATION lib)


