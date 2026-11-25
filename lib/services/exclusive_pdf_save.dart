// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:typed_data';

import 'exclusive_file_save.dart';

/// PDF-specific entry point for no-replace publication.
class ExclusivePdfSave {
  static bool get supported => ExclusiveFileSave.supported;

  static Future<void> save({
    required String path,
    required Uint8List bytes,
    required Directory libraryRoot,
    Future<void> Function()? beforePublish,
  }) => ExclusiveFileSave.save(
    path: path,
    bytes: bytes,
    libraryRoot: libraryRoot,
    extension: '.pdf',
    beforePublish: beforePublish,
  );
}
