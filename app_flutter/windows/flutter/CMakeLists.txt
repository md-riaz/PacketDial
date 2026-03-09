# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.

# Serves the same purpose as list(TRANSFORM ... PREPEND ...),
# which isn't available in 3.14.
function(list_prepend LIST_NAME PREFIX)
    set(NEW_LIST "")
    foreach(element ${${LIST_NAME}})
        list(APPEND NEW_LIST "${PREFIX}${element}")
    endforeach(element)
    set(${LIST_NAME} "${NEW_LIST}" PARENT_SCOPE)
endfunction()

# === Flutter Library ===
# System-level dependencies.
find_package(PkgConfig QUIET)

set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_BINARY_DIR}/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
list_prepend(FLUTTER_LIBRARY_HEADERS "${EPHEMERAL_DIR}/")
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}.lib")
add_dependencies(flutter flutter_assemble)

# === Flutter C++ wrapper library sources ===
# These are generated into ephemeral/cpp_client_wrapper/ by flutter_assemble
# (tool_backend.bat) at build time.  Define the paths before the custom command
# so they can be listed as OUTPUT, which tells MSBuild that this command
# produces them and that flutter_wrapper_app should be compiled afterwards.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")
set(WRAPPER_SRCS
  "${WRAPPER_ROOT}/core_implementations.cc"
  "${WRAPPER_ROOT}/flutter_engine.cc"
  "${WRAPPER_ROOT}/flutter_view_controller.cc"
  "${WRAPPER_ROOT}/plugin_registrar.cc"
  "${WRAPPER_ROOT}/standard_codec.cc"
)

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this command to always run.
# Mark it SYMBOLIC so MSBuild suppresses the "output not created" warning.
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_phony_")
set_source_files_properties("${PHONY_OUTPUT}" PROPERTIES SYMBOLIC TRUE)
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS}
    ${WRAPPER_SRCS}
    ${PHONY_OUTPUT}
  COMMAND ${CMAKE_COMMAND} -E env
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
      windows-x64 $<CONFIG>
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
)

# === Flutter C++ wrapper library ===
# Provides the high-level C++ API: dart_project.h, flutter_view_controller.h,
# plugin_registry.h, etc.  Mark sources as GENERATED so CMake does not look
# for them at configure time — they appear via the flutter_assemble OUTPUT
# above once tool_backend.bat has run.
set_source_files_properties(${WRAPPER_SRCS} PROPERTIES GENERATED TRUE)
add_library(flutter_wrapper_app STATIC ${WRAPPER_SRCS})
apply_standard_settings(flutter_wrapper_app)
set_target_properties(flutter_wrapper_app PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_app PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_include_directories(flutter_wrapper_app PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_app flutter_assemble)

# === Flutter C++ wrapper library (plugin variant) ===
# Plugins link against flutter_wrapper_plugin to get access to the
# C++ wrapper headers (flutter/method_channel.h, etc.).  It is identical
# to flutter_wrapper_app but kept as a separate target so that plugins
# compile as SHARED libraries while the app compiles its own copy STATIC.
add_library(flutter_wrapper_plugin STATIC ${WRAPPER_SRCS})
apply_standard_settings(flutter_wrapper_plugin)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_plugin PUBLIC flutter)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)
