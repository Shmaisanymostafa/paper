// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';

/// Metadata candidates, not validated PDFs. Call only after explicit folder
/// selection. Mobile provider URIs require a native permission-aware adapter;
/// they must not be converted into guessed filesystem paths.
class FolderPdfCandidate {
  const FolderPdfCandidate(this.path, this.bytes);
  final String path;
  final int bytes;
}

class FolderDiscoveryResult {
  const FolderDiscoveryResult(this.candidates, {required this.incomplete});
  final List<FolderPdfCandidate> candidates;
  final bool incomplete;
}

/// Shallow, read-only discovery. Skips root and entry symlinks; ancestor links
/// are not a sandbox boundary. Never recursively scans a
/// device. No file bytes, network calls, persistence, or permission requests.
/// Metadata remains a snapshot: import must revalidate type/size and content.
class FolderDiscovery {
  Future<FolderDiscoveryResult> scan(
    Directory selected, {
    int maxEntries = 500,
    bool Function()? cancelled,
  }) async {
    if (maxEntries < 1 || maxEntries > 5000) {
      throw ArgumentError.value(maxEntries, 'maxEntries');
    }
    final candidates = <FolderPdfCandidate>[];
    var incomplete = false;
    var visited = 0;
    if (cancelled?.call() == true) {
      return const FolderDiscoveryResult([], incomplete: true);
    }
    // Reject a linked root too; the OS-selected folder must be a real local
    // directory. This is not a defense against hostile concurrent replacement.
    if (await FileSystemEntity.type(selected.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException('Selected folder is unavailable');
    }
    if (cancelled?.call() == true) {
      return const FolderDiscoveryResult([], incomplete: true);
    }
    try {
      await for (final entry in selected.list(followLinks: false)) {
        if (cancelled?.call() == true || visited >= maxEntries) {
          incomplete = true;
          break;
        }
        visited++;
        if (entry is! File || !entry.path.toLowerCase().endsWith('.pdf')) {
          continue;
        }
        try {
          if (await FileSystemEntity.type(entry.path, followLinks: false) !=
              FileSystemEntityType.file) {
            incomplete = true;
            continue;
          }
          if (cancelled?.call() == true) {
            incomplete = true;
            break;
          }
          final stat = await entry.stat();
          if (cancelled?.call() == true) {
            incomplete = true;
            break;
          }
          if (stat.type == FileSystemEntityType.file && stat.size > 0) {
            candidates.add(FolderPdfCandidate(entry.path, stat.size));
          }
        } on FileSystemException {
          incomplete = true;
        }
      }
    } on FileSystemException {
      incomplete = true;
    }
    incomplete = incomplete || cancelled?.call() == true;
    candidates.sort((a, b) => a.path.compareTo(b.path));
    return FolderDiscoveryResult(
      List.unmodifiable(candidates),
      incomplete: incomplete,
    );
  }
}
