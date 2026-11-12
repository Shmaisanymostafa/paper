import 'dart:io';

/// Refuse Dart HTTP requests, including accidental remote-font requests from
/// dependencies. Build-time dependency downloads are separate from app runtime.
class OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const HttpException('Cave Paper does not make network requests.');
}
