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
# Locate voip_core.dll (Rust core) relative to the Flutter project root.
# PROJECT_DIR is set by the Flutter tool (generated_config.cmake) and always
# points to the canonical project path (e.g. X:\app_flutter). Going up one
# level gives the repository root, regardless of drive letter mapping.
get_filename_component(REPO_ROOT "${PROJECT_DIR}" DIRECTORY)
set(CORE_RUST_DIR "${REPO_ROOT}/core_rust")

# Paths for debug and release DLLs.
set(VOIP_CORE_DLL_DEBUG   "${CORE_RUST_DIR}/target/x86_64-pc-windows-msvc/debug/voip_core.dll")
set(VOIP_CORE_DLL_RELEASE "${CORE_RUST_DIR}/target/x86_64-pc-windows-msvc/release/voip_core.dll")

# Post-build copy: use PowerShell so the copy is skipped gracefully when the
# DLL does not yet exist (cmake copy_if_different exits 1 in that case).
# The $<IF:...> generator expression selects debug vs release at build time.
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
    "$src = '$<IF:$<CONFIG:Release>,${VOIP_CORE_DLL_RELEASE},${VOIP_CORE_DLL_DEBUG}>'; if (Test-Path $src) { Copy-Item -Force $src '$<TARGET_FILE_DIR:${BINARY_NAME}>' } else { Write-Host 'voip_core.dll not found, skipping copy.' }"
  COMMENT "Copying voip_core.dll to output directory (if present)"
  VERBATIM
)



