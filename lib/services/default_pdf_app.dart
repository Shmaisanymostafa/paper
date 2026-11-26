// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/services.dart';

/// The app the OS opens PDFs with right now.
typedef PdfHandler = ({String package, String label, bool isSelf});

/// Help for choosing Cave Paper as the PDF app. The app never changes the OS
/// default itself: it shows the person the steps, on Android says which app
/// opens PDFs now and links to that app's settings page, and on Windows opens
/// the Default apps page where they choose. On every platform the PDF file icon
/// follows whichever app is the default.
class DefaultPdfApp {
  DefaultPdfApp({
    String? platform,
    Future<void> Function(String executable, List<String> arguments)? start,
  }) : platform = platform ?? Platform.operatingSystem,
       _start = start ?? _startDetached;

  static const channel = MethodChannel('technology.cave.paper/defaults');

  final String platform;
  final Future<void> Function(String, List<String>) _start;

  static Future<void> _startDetached(String executable, List<String> args) =>
      Process.start(executable, args, mode: ProcessStartMode.detached);

  /// Localized string key with this platform's steps.
  String get stepsKey => switch (platform) {
    'android' => 'defaultAppAndroid',
    'ios' => 'defaultAppIos',
    'macos' => 'defaultAppMacos',
    'windows' => 'defaultAppWindows',
    _ => 'defaultAppLinux',
  };

  bool get canOpenSettings => platform == 'windows';

  /// Whether [currentHandler] can say which app opens PDFs.
  bool get canDetectHandler => platform == 'android';

  /// Opens Windows Settings › Apps › Default apps. The person still chooses.
  Future<void> openSettings() {
    if (!canOpenSettings) throw UnsupportedError('No settings page');
    return _start('explorer.exe', const ['ms-settings:defaultapps']);
  }

  /// Android only: the app that opens PDFs without asking, or null when
  /// Android would let the person choose (or the answer is unknown).
  Future<PdfHandler?> currentHandler() async {
    if (!canDetectHandler) return null;
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'pdfHandler',
      );
      final package = result?['package'], label = result?['label'];
      if (package is! String || label is! String || package.isEmpty) {
        return null;
      }
      return (
        package: package,
        label: label.trim().isEmpty ? package : label.trim(),
        isSelf: result?['self'] == true,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Android only: opens the App info page of [handler], where the person
  /// taps "Open by default" to clear it. Returns false if it could not open.
  Future<bool> openHandlerSettings(PdfHandler handler) async {
    if (!canDetectHandler || handler.isSelf) return false;
    try {
      return await channel.invokeMethod<bool>(
            'openAppSettings',
            handler.package,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
