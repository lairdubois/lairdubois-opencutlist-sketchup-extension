# -------------------------------------------------------------------
#                             Packy

# -------------------------------------------------------------------
#                             extern

add_subdirectory(extern)

# -------------------------------------------------------------------

if(WIN32)
  add_compile_definitions(LIBPACKY_EXPORTS)
else()
  add_compile_options(-fPIC)
endif()

# Library headers
set(LIBRARY_HEADERS
        include/shape/labeling.hpp
        include/packy.hpp
        src/solver.hpp
        src/solver_builder.hpp
)
source_group("Headers" FILES ${LIBRARY_HEADERS})

# Library sources
if(WIN32)
  set(LIBRARY_SOURCES
          src/labeling.cpp
          src/packy.cpp
          src/dllmain.cpp
  )
else()
  set(LIBRARY_SOURCES
          src/labeling.cpp
          src/packy.cpp
  )
endif()
source_group("Sources" FILES ${LIBRARY_SOURCES})

if(WIN32)
  include(GenerateExportHeader)
endif()

add_library(Packy SHARED ${LIBRARY_HEADERS} ${LIBRARY_SOURCES})

if(WIN32)
  generate_export_header(Packy
          BASE_NAME Packy
          EXPORT_MACRO_NAME Packy_EXPORT
          EXPORT_FILE_NAME Packy_Export.h
          STATIC_DEFINE Packy_BUILT_AS_STATIC
  )
endif()

target_include_directories(Packy PUBLIC include)
target_link_libraries(Packy PUBLIC PackingSolver::onedimensional)
target_link_libraries(Packy PUBLIC PackingSolver::rectangle)
target_link_libraries(Packy PUBLIC PackingSolver::rectangleguillotine)
target_link_libraries(Packy PUBLIC PackingSolver::irregular)
target_compile_features(Packy PRIVATE cxx_std_17)

install(TARGETS Packy RUNTIME DESTINATION lib)

# -------------------------------------------------------------------
#                           Debug executable

if(OCL_BUILD_DEBUG_EXECUTABLES)

  add_executable(PackyMain ${LIBRARY_HEADERS} ${LIBRARY_SOURCES} src/main.cpp)
  target_include_directories(PackyMain PUBLIC include)
  target_link_libraries(PackyMain PUBLIC PackingSolver::onedimensional)
  target_link_libraries(PackyMain PUBLIC PackingSolver::rectangle)
  target_link_libraries(PackyMain PUBLIC PackingSolver::rectangleguillotine)
  target_link_libraries(PackyMain PUBLIC PackingSolver::irregular)
  target_link_libraries(PackyMain PUBLIC Boost::program_options)
  target_compile_features(PackyMain PRIVATE cxx_std_17)

  install(TARGETS PackyMain RUNTIME DESTINATION lib)

endif()
