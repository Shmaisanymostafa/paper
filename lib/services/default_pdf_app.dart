// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'dart:io';

/// Help for choosing Cave Paper as the PDF app. The app never changes the OS
/// default itself: it shows the person the steps, and on Windows opens the
/// Default apps page where they choose. On every platform the PDF file icon
/// follows whichever app is the default.
class DefaultPdfApp {
  DefaultPdfApp({
    String? platform,
    Future<void> Function(String executable, List<String> arguments)? start,
  }) : platform = platform ?? Platform.operatingSystem,
       _start = start ?? _startDetached;

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

  /// Opens Windows Settings › Apps › Default apps. The person still chooses.
  Future<void> openSettings() {
    if (!canOpenSettings) throw UnsupportedError('No settings page');
    return _start('explorer.exe', const ['ms-settings:defaultapps']);
  }
}
