cmake_minimum_required(VERSION 3.22)
project(voip_core C CXX)

set(VOIP_CORE_PJSIP_ROOT "" CACHE PATH "Directory containing staged PJSIP include/ and lib/ folders")
set(VOIP_CORE_OPENSSL_ROOT "" CACHE PATH "Directory containing staged OpenSSL lib/ and include/ folders")

add_library(voip_core SHARED
  src/core/engine_bridge.c
  src/shim/pjsip_shim.c
)

set_target_properties(voip_core PROPERTIES
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

if(ANDROID)
  target_compile_definitions(voip_core PRIVATE
    PJ_AUTOCONF=1
    PJ_IS_BIG_ENDIAN=0
    PJ_IS_LITTLE_ENDIAN=1
  )
endif()

target_include_directories(voip_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src/shim
)

if(VOIP_CORE_PJSIP_ROOT AND EXISTS "${VOIP_CORE_PJSIP_ROOT}/include")
  target_include_directories(voip_core PRIVATE
    ${VOIP_CORE_PJSIP_ROOT}/include
  )
endif()

if(VOIP_CORE_PJSIP_ROOT AND EXISTS "${VOIP_CORE_PJSIP_ROOT}/lib")
  target_link_directories(voip_core PRIVATE ${VOIP_CORE_PJSIP_ROOT}/lib)

  if(WIN32)
    target_link_libraries(voip_core PRIVATE
      libpjproject-x86_64-x64-vc14-Release
      pjlib-util-x86_64-x64-vc14-Release
      pjlib-x86_64-x64-vc14-Release
      pjmedia-audiodev-x86_64-x64-vc14-Release
      pjmedia-codec-x86_64-x64-vc14-Release
      pjmedia-x86_64-x64-vc14-Release
      pjnath-x86_64-x64-vc14-Release
      pjsip-core-x86_64-x64-vc14-Release
      pjsip-simple-x86_64-x64-vc14-Release
      pjsip-ua-x86_64-x64-vc14-Release
      pjsua-lib-x86_64-x64-vc14-Release
      libspeex-x86_64-x64-vc14-Release
      libresample-x86_64-x64-vc14-Release
      libsrtp-x86_64-x64-vc14-Release
      ws2_32
      winmm
      ole32
      uuid
      crypt32
      avrt
    )
  elseif(ANDROID)
    file(GLOB VOIP_CORE_PJLIB_ARCHIVE "${VOIP_CORE_PJSIP_ROOT}/lib/libpj-*.a")
    list(LENGTH VOIP_CORE_PJLIB_ARCHIVE VOIP_CORE_PJLIB_ARCHIVE_COUNT)
    if(VOIP_CORE_PJLIB_ARCHIVE_COUNT LESS 1)
      message(FATAL_ERROR "Could not infer Android PJSIP archive suffix from ${VOIP_CORE_PJSIP_ROOT}/lib")
    endif()

    list(GET VOIP_CORE_PJLIB_ARCHIVE 0 VOIP_CORE_PJLIB_ARCHIVE_PATH)
    get_filename_component(VOIP_CORE_PJLIB_ARCHIVE_NAME "${VOIP_CORE_PJLIB_ARCHIVE_PATH}" NAME)
    string(REGEX REPLACE "^libpj-(.*)\\.a$" "\\1" VOIP_CORE_PJSIP_SUFFIX "${VOIP_CORE_PJLIB_ARCHIVE_NAME}")

    target_link_libraries(voip_core PRIVATE
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjsua-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjsip-ua-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjsip-simple-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjsip-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjsdp-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjmedia-codec-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjmedia-audiodev-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjmedia-videodev-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjmedia-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjnath-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpjlib-util-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libpj-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libsrtp-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libspeex-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libgsmcodec-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libilbccodec-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libg7221codec-${VOIP_CORE_PJSIP_SUFFIX}.a"
      "${VOIP_CORE_PJSIP_ROOT}/lib/libresample-${VOIP_CORE_PJSIP_SUFFIX}.a"
      OpenSLES
      log
      android
      mediandk
      EGL
      GLESv2
      atomic
      m
    )
  else()
    target_link_libraries(voip_core PRIVATE
      pjsua-lib
      pjsip-ua
      pjsip-simple
      pjsip
      pjsdp
      pjmedia-codec
      pjmedia-audiodev
      pjmedia-videodev
      pjmedia
      pjnath
      pjlib-util
      pjlib
      srtp
      speex
      gsmcodec
      ilbccodec
      g7221codec
      resample
      m
      log
      OpenSLES
    )
  endif()
endif()

if(VOIP_CORE_OPENSSL_ROOT AND EXISTS "${VOIP_CORE_OPENSSL_ROOT}/lib")
  target_include_directories(voip_core PRIVATE ${VOIP_CORE_OPENSSL_ROOT}/include)
  target_link_directories(voip_core PRIVATE ${VOIP_CORE_OPENSSL_ROOT}/lib)
endif()
