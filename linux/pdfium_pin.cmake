# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT
#
# One PDFium for the whole app (Linux).
#
# pdfrx 2.12.0 (via pdfium_dart 0.4.1) bundles PDFium chromium/8125 as libpdfium.so.
# The printing 5.15.1 plugin downloads its own PDFium (default chromium/5200)
# and bundles it under the same file name into the same folder, so one copy
# silently overwrote the other. Pinning the printing plugin to pdfrx's release
# makes both copies the same build, and cave_verify_bundled_pdfium() refuses
# to finish the install if the bundled library is not exactly that build.
#
# Provenance and archive hashes: docs/native-pdfium-windows-linux.json.
# When pdfrx/pdfium_dart changes its PDFium release, update this file and that
# record together. Include this file BEFORE flutter/generated_plugins.cmake.

set(CAVE_PDFIUM_RELEASE "8125")
set(PDFIUM_VERSION "${CAVE_PDFIUM_RELEASE}" CACHE STRING
  "PDFium release; pinned to the one pdfrx bundles" FORCE)

# Flutter passes FLUTTER_TARGET_PLATFORM (linux-x64 / linux-arm64).
if(NOT DEFINED FLUTTER_TARGET_PLATFORM)
  message(FATAL_ERROR "FLUTTER_TARGET_PLATFORM is not set; build with flutter build linux.")
endif()
string(REPLACE "linux-" "" _cave_pdfium_arch "${FLUTTER_TARGET_PLATFORM}")
if(_cave_pdfium_arch STREQUAL "x64")
  set(CAVE_PDFIUM_SHA256 "1c251efce460d67437a4c76d4be9033ae2f17bf5603f5bff1af10209b94ca723")
elseif(_cave_pdfium_arch STREQUAL "arm64")
  set(CAVE_PDFIUM_SHA256 "8cdc437dce84a6493b9ec6c4f5ad9ff2c299e505acfd7b0ad38cb440805b2c70")
else()
  message(FATAL_ERROR
    "No pinned PDFium hash for target '${_cave_pdfium_arch}'. "
    "Record one in linux/pdfium_pin.cmake before building.")
endif()

# Call after every other install() rule: fails the install unless the single
# bundled PDFium in LIB_DIR matches the pinned SHA-256.
function(cave_verify_bundled_pdfium LIB_DIR)
  install(CODE "
    set(_cave_lib \"${LIB_DIR}/libpdfium.so\")
    if(NOT EXISTS \"\${_cave_lib}\")
      message(FATAL_ERROR \"Bundled PDFium is missing: \${_cave_lib}\")
    endif()
    file(SHA256 \"\${_cave_lib}\" _cave_hash)
    if(NOT _cave_hash STREQUAL \"${CAVE_PDFIUM_SHA256}\")
      message(FATAL_ERROR
        \"Bundled PDFium \${_cave_lib} has SHA-256 \${_cave_hash}; \"
        \"expected chromium/${CAVE_PDFIUM_RELEASE} ${CAVE_PDFIUM_SHA256}. \"
        \"See linux/pdfium_pin.cmake.\")
    endif()
    message(STATUS \"Verified bundled PDFium chromium/${CAVE_PDFIUM_RELEASE}: \${_cave_hash}\")
  " COMPONENT Runtime)
endfunction()
