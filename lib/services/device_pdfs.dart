// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// A PDF found on the device. Listing reads names and sizes only; bytes are
/// read (and copied into the library) only when the person opens one.
class DevicePdf {
  const DevicePdf({
    required this.path,
    required this.bytes,
    required this.modified,
  });
  final String path;
  final int bytes;
  final DateTime modified;
  String get name => p.basename(path);
}

class DeviceScanResult {
  const DeviceScanResult(this.files, {required this.incomplete});
  final List<DevicePdf> files;

  /// True when a limit stopped the walk early.
  final bool incomplete;
}

/// Directory names that never hold the person's documents, or are too large
/// to walk. Hidden (dot) folders are skipped as well.
const _skippedNames = {
  'node_modules',
  'AppData',
  r'$RECYCLE.BIN',
  'System Volume Information',
};

/// Recursive, read-only walk of [roots]. Never follows links, so it cannot
/// leave a root or loop. Unreadable folders are skipped silently. Results are
/// newest first. Pure dart:io so it can run in a background isolate.
DeviceScanResult scanForPdfs(
  List<String> roots, {
  int maxResults = 5000,
  int maxEntries = 250000,
  int maxDepth = 24,
}) {
  final found = <String, DevicePdf>{};
  var visited = 0;
  var incomplete = false;
  for (final root in roots) {
    if (FileSystemEntity.typeSync(root, followLinks: false) !=
        FileSystemEntityType.directory) {
      continue;
    }
    final stack = <(Directory, int)>[(Directory(root), 0)];
    while (stack.isNotEmpty && !incomplete) {
      final (directory, depth) = stack.removeLast();
      final List<FileSystemEntity> entries;
      try {
        entries = directory.listSync(followLinks: false);
      } on FileSystemException {
        continue;
      }
      for (final entry in entries) {
        if (++visited > maxEntries || found.length >= maxResults) {
          incomplete = true;
          break;
        }
        final name = p.basename(entry.path);
        if (name.startsWith('.')) continue;
        if (entry is Directory) {
          if (depth + 1 > maxDepth || _skippedNames.contains(name)) continue;
          // Android/data and Android/obb hold other apps' private files;
          // Android/media is kept because messaging apps save documents there.
          final parent = p.basename(directory.path);
          if (parent == 'Android' && (name == 'data' || name == 'obb')) {
            continue;
          }
          stack.add((entry, depth + 1));
        } else if (entry is File && name.toLowerCase().endsWith('.pdf')) {
          try {
            final stat = entry.statSync();
            if (stat.type == FileSystemEntityType.file && stat.size >= 8) {
              found[entry.path] = DevicePdf(
                path: entry.path,
                bytes: stat.size,
                modified: stat.modified,
              );
            }
          } on FileSystemException {
            continue;
          }
        }
      }
    }
    if (incomplete) break;
  }
  final files = found.values.toList()
    ..sort((a, b) {
      final order = b.modified.compareTo(a.modified);
      return order != 0 ? order : a.path.compareTo(b.path);
    });
  return DeviceScanResult(List.unmodifiable(files), incomplete: incomplete);
}

/// Presentation-only filter and order for the device list: newest first, or
/// by file name. Never touches the files.
List<DevicePdf> deviceListing(
  Iterable<DevicePdf> files, {
  required String query,
  bool byName = false,
}) {
  final needle = query.trim().toLowerCase();
  final result = files
      .where((f) => f.name.toLowerCase().contains(needle))
      .toList();
  result.sort((a, b) {
    final order = byName
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.modified.compareTo(a.modified);
    return order != 0 ? order : a.path.compareTo(b.path);
  });
  return result;
}

enum DeviceAccess {
  /// Folders can be listed now.
  granted,

  /// Android has not granted access yet; [DevicePdfs.request] asks.
  denied,

  /// The OS asked the person in its own screen; check again on resume.
  pending,

  /// This platform cannot list device files (iOS), or the OS refused.
  unavailable,
}

/// Where and how "On this device" looks, per platform:
/// - Android: whole shared storage, after the person grants All files access.
/// - Windows/Linux: Desktop, Documents and Downloads in the home folder.
/// - macOS: only folders the person picks (the app sandbox forbids more).
/// - iOS: not offered.
class DevicePdfs {
  DevicePdfs({String? platform, Map<String, String>? environment})
    : platform = platform ?? Platform.operatingSystem,
      _environment = environment ?? Platform.environment;

  static const channel = MethodChannel('technology.cave.paper/storage');
  final String platform;
  final Map<String, String> _environment;

  bool get supported => platform != 'ios';

  /// True when the app can find PDFs without the person choosing a folder.
  bool get automatic =>
      platform == 'android' || platform == 'windows' || platform == 'linux';

  /// True when the person can add a folder with the system folder picker.
  bool get folderPicker =>
      platform == 'macos' || platform == 'windows' || platform == 'linux';

  Future<DeviceAccess> status() async {
    if (!supported) return DeviceAccess.unavailable;
    if (platform != 'android') return DeviceAccess.granted;
    return _parse(await channel.invokeMethod<String>('status'));
  }

  Future<DeviceAccess> request() async {
    if (platform != 'android') return status();
    return _parse(await channel.invokeMethod<String>('request'));
  }

  DeviceAccess _parse(String? value) => switch (value) {
    'granted' => DeviceAccess.granted,
    'denied' => DeviceAccess.denied,
    'pending' => DeviceAccess.pending,
    _ => DeviceAccess.unavailable,
  };

  /// Folders searched automatically. Empty on macOS and iOS.
  Future<List<String>> roots() async {
    switch (platform) {
      case 'android':
        return await channel.invokeListMethod<String>('roots') ?? const [];
      case 'windows':
      case 'linux':
        final home =
            _environment[platform == 'windows' ? 'USERPROFILE' : 'HOME'];
        if (home == null || home.isEmpty) return const [];
        final context = platform == 'windows' ? p.windows : p.posix;
        return [
          for (final name in const ['Desktop', 'Documents', 'Downloads'])
            context.join(home, name),
        ];
      default:
        return const [];
    }
  }

  /// Walks [roots] on a background isolate so the interface stays smooth.
  Future<DeviceScanResult> scan(List<String> roots) {
    final copy = List<String>.of(roots);
    return Isolate.run(() => scanForPdfs(copy));
  }
}
