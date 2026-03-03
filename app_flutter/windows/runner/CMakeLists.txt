cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "run_loop.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Note: Flutter now handles asset placement internally. Modern Flutter versions
# assemble assets directly into runner/Release/data/flutter_assets during the
# flutter_assemble step, so manual copying is no longer needed.

# Copy voip_core.dll (Rust core) next to the exe at build time if it exists.
# For Debug builds: cd core_rust && cargo build --target x86_64-pc-windows-msvc
# For Release builds: cd core_rust && cargo build --release --target x86_64-pc-windows-msvc
#
# Try to find the DLL in this order:
# 1. Target-specific path matching the CMake build configuration (debug/release)
# 2. Non-target-specific path (target/debug or target/release)
set(CORE_RUST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../core_rust")

# Determine which Rust build profile to use based on CMake configuration
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  set(RUST_PROFILE "release")
else()
  # Debug and Profile both use debug Rust builds (faster compilation for dev)
  set(RUST_PROFILE "debug")
endif()

# Try target-specific path first (preferred when using --target flag)
set(VOIP_CORE_DLL_TARGET "${CORE_RUST_DIR}/target/x86_64-pc-windows-msvc/${RUST_PROFILE}/voip_core.dll")
# Fallback to non-target-specific path
set(VOIP_CORE_DLL_FALLBACK "${CORE_RUST_DIR}/target/${RUST_PROFILE}/voip_core.dll")

if(EXISTS "${VOIP_CORE_DLL_TARGET}")
  set(VOIP_CORE_DLL "${VOIP_CORE_DLL_TARGET}")
  message(STATUS "Found voip_core.dll at: ${VOIP_CORE_DLL}")
elseif(EXISTS "${VOIP_CORE_DLL_FALLBACK}")
  set(VOIP_CORE_DLL "${VOIP_CORE_DLL_FALLBACK}")
  message(STATUS "Found voip_core.dll at: ${VOIP_CORE_DLL}")
else()
  set(VOIP_CORE_DLL "")
  message(STATUS "voip_core.dll not found. Build it with: cd core_rust && cargo build $<IF:$<CONFIG:Release>,--release,> --target x86_64-pc-windows-msvc")
endif()

if(VOIP_CORE_DLL)
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${VOIP_CORE_DLL}
      $<TARGET_FILE_DIR:${BINARY_NAME}>
    COMMENT "Copying voip_core.dll to output directory"
  )
endif()
