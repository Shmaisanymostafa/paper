# Copyright (c) 2026 Cave. See AUTHORS.md.
# SPDX-License-Identifier: MIT
#
# One PDFium for the whole app (Windows).
#
# pdfrx 2.12.0 (via pdfium_dart 0.4.1) bundles PDFium chromium/8125 as pdfium.dll.
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

# Flutter passes FLUTTER_TARGET_PLATFORM (windows-x64 / windows-arm64); its
# own default is windows-x64.
if(DEFINED FLUTTER_TARGET_PLATFORM)
  string(REPLACE "windows-" "" _cave_pdfium_arch "${FLUTTER_TARGET_PLATFORM}")
else()
  set(_cave_pdfium_arch "x64")
endif()
if(_cave_pdfium_arch STREQUAL "x64")
  set(CAVE_PDFIUM_SHA256 "4b0dec92555d69437bef0df37be630181ab3e83a6823ca264ede355a4f2ef994")
elseif(_cave_pdfium_arch STREQUAL "arm64")
  set(CAVE_PDFIUM_SHA256 "61b3500520d2f7ec2f8074851ba941b1470e85b8849e6efe5966ef2ce676c1f3")
else()
  message(FATAL_ERROR
    "No pinned PDFium hash for target '${_cave_pdfium_arch}'. "
    "Record one in windows/pdfium_pin.cmake before building.")
endif()

# Call after every other install() rule: fails the install unless the single
# bundled PDFium in LIB_DIR matches the pinned SHA-256.
function(cave_verify_bundled_pdfium LIB_DIR)
  install(CODE "
    set(_cave_lib \"${LIB_DIR}/pdfium.dll\")
    if(NOT EXISTS \"\${_cave_lib}\")
      message(FATAL_ERROR \"Bundled PDFium is missing: \${_cave_lib}\")
    endif()
    file(SHA256 \"\${_cave_lib}\" _cave_hash)
    if(NOT _cave_hash STREQUAL \"${CAVE_PDFIUM_SHA256}\")
      message(FATAL_ERROR
        \"Bundled PDFium \${_cave_lib} has SHA-256 \${_cave_hash}; \"
        \"expected chromium/${CAVE_PDFIUM_RELEASE} ${CAVE_PDFIUM_SHA256}. \"
        \"See windows/pdfium_pin.cmake.\")
    endif()
    message(STATUS \"Verified bundled PDFium chromium/${CAVE_PDFIUM_RELEASE}: \${_cave_hash}\")
  " COMPONENT Runtime)
endfunction()
