import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/library.dart';

typedef _LinkNative = Int32 Function(Pointer<Uint8>, Pointer<Uint8>);
typedef _MallocNative = Pointer<Void> Function(UintPtr);
typedef _FreeNative = Void Function(Pointer<Void>);

/// POSIX no-replace publication: writes a private staged file completely before
/// atomically linking it to the chosen name. The destination is never opened for
/// writing, including when another process creates or replaces it concurrently.
class ExclusivePdfSave {
  static bool get supported => Platform.isMacOS || Platform.isLinux;

  static Future<void> save({
    required String path,
    required Uint8List bytes,
    required Directory libraryRoot,
    // Deterministic race/failure test seam, not used by the app UI.
    Future<void> Function()? beforePublish,
  }) async {
    if (!supported ||
        bytes.isEmpty ||
        path.contains('\u0000') ||
        !p.isAbsolute(path) ||
        !path.toLowerCase().endsWith('.pdf')) {
      throw const LibraryFormatException('Choose a new PDF filename.');
    }
    final parent = await Directory(p.dirname(path)).resolveSymbolicLinks();
    final root = await libraryRoot.resolveSymbolicLinks();
    final destination = p.join(parent, p.basename(path));
    if (p.equals(root, parent) || p.isWithin(root, destination)) {
      throw const LibraryFormatException(
        'Choose a location outside the library.',
      );
    }
    final staging = await Directory(parent).createTemp('.paper-copy-');
    try {
      final staged = File(p.join(staging.path, 'copy.pdf'));
      await staged.writeAsBytes(bytes, flush: true);
      await beforePublish?.call();
      _linkNoReplace(staged.path, destination);
    } finally {
      // Never remove a user-selected destination, including after failures.
      // A cleanup failure can leave only our private staging copy behind.
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        /* Keep evidence; publication outcome is unchanged. */
      }
    }
  }

  static void _linkNoReplace(String source, String target) {
    final native = DynamicLibrary.process();
    final malloc = native
        .lookupFunction<_MallocNative, Pointer<Void> Function(int)>('malloc');
    final free = native
        .lookupFunction<_FreeNative, void Function(Pointer<Void>)>('free');
    final link = native
        .lookupFunction<
          _LinkNative,
          int Function(Pointer<Uint8>, Pointer<Uint8>)
        >('link');
    Pointer<Uint8> string(String value) {
      final data = utf8.encode(value);
      final memory = malloc(data.length + 1).cast<Uint8>();
      if (memory == nullptr) throw StateError('Native allocation failed.');
      memory.asTypedList(data.length + 1).setAll(0, [...data, 0]);
      return memory;
    }

    final from = string(source);
    try {
      final to = string(target);
      try {
        if (link(from, to) != 0) {
          throw FileSystemException(
            'Cannot publish new PDF without replacing an existing path.',
            target,
          );
        }
      } finally {
        free(to.cast());
      }
    } finally {
      free(from.cast());
    }
  }
}
