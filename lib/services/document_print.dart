import 'dart:typed_data';
import 'dart:io';

import 'package:pdf/pdf.dart';

import 'package:crypto/crypto.dart';
import 'package:printing/printing.dart';

import '../data/library_repository.dart';
import '../domain/library.dart';
import 'document_share.dart';

class DocumentPrintException implements Exception {
  const DocumentPrintException(this.messageKey);
  final String messageKey;
}

/// Sends the unchanged PDF only after explicit UI confirmation.
/// The OS dialog chooses printer and copies. This version prints all pages. Never prints silently.
class DocumentPrint {
  DocumentPrint({
    Future<bool> Function(Uint8List, String, PdfPageFormat)? print,
  }) : _print = print ?? _systemPrint;

  static bool get supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static const maxPrintBytes = 64 * 1024 * 1024;
  final Future<bool> Function(Uint8List, String, PdfPageFormat) _print;
  bool _busy = false;

  static Future<bool> _systemPrint(
    Uint8List bytes,
    String name,
    PdfPageFormat format,
  ) => Printing.layoutPdf(
    name: name,
    format: format,
    dynamicLayout: false,
    onLayout: (_) async => bytes,
  );

  Future<void> print({
    required LibraryRepository repository,
    required PaperDocument document,
    required bool encrypted,
    required bool allowsPrinting,
    required double pageWidth,
    required double pageHeight,
    required bool uniformPages,
    bool Function()? isActive,
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      // No password handling/decryption or bypass of document restrictions.
      if (encrypted || !allowsPrinting) {
        throw const DocumentPrintException('printProtected');
      }
      if (!uniformPages ||
          !pageWidth.isFinite ||
          !pageHeight.isFinite ||
          pageWidth <= 0 ||
          pageHeight <= 0) {
        throw const DocumentPrintException('printPageSizes');
      }
      if (document.byteLength > maxPrintBytes) {
        throw const DocumentPrintException('printTooLarge');
      }
      final file = repository.documentFile(document.id);
      if (await file.length() > maxPrintBytes) {
        throw const DocumentPrintException('printTooLarge');
      }
      // Bound memory even if an external process replaces/grows the copy.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        if (builder.length + chunk.length > maxPrintBytes) {
          throw const DocumentPrintException('printTooLarge');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length != document.byteLength ||
          sha256.convert(bytes).toString() != document.id) {
        throw const DocumentPrintException('printChanged');
      }
      if (isActive != null && !isActive()) return;
      // Completion means the OS accepted/dismissed the dialog, not paper delivery.
      await _print(
        bytes,
        '${DocumentShare.safeName(document.title)}.pdf',
        PdfPageFormat(pageWidth, pageHeight),
      );
    } finally {
      _busy = false;
    }
  }
}
