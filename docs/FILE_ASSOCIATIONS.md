# Default PDF viewer / open-with status

macOS source advertises `com.adobe.pdf` as Viewer with Alternate rank. The
native adapter queues cold launches and delivers warm open events. Flutter
imports a validated managed copy before opening it; original files remain unchanged.
Security-scoped access is released after import. Multiple files open sequentially.
The user chooses Finder > Get Info > Open with > Change All, if desired.
The app never changes system defaults automatically.

Current verification (2026-11-17): Dart adapter tests, analyzer and platform metadata regression tests pass. The actual macOS LaunchServices database lists the built app as a com.adobe.pdf Viewer/Alternate with PaperPDF.icns. No system default was changed. The iOS simulator build succeeds; native file-provider/Open In runtime tests are still pending. Native cold/warm
launch, multiple-file, denied-file, sandbox and installed-app association tests
remain required. This is not a verified macOS handler release.

Windows and Linux source adapters are now present; see their platform checklists. On iOS,
Open In / document import does not imply a universal default PDF reader setting.
On Windows, the selected default application's ProgID controls the PDF file
icon; Cave Paper cannot promise its icon while another app is the default.

Approved app/logo and PDF file-icon originals are preserved separately for
packaging; platform app icons and Windows/macOS document icon containers are packaged. Do not publish
unapproved substitutions or claim these features shipped.

## Mobile continuation

Android now advertises ACTION_VIEW application/pdf for content/file URIs,
handles initial and subsequent intents, copies off the UI thread with a 200MiB
limit and releases only temporary files it owns. Each copy keeps the provider's
display name, so the library title matches the original file. ACTION_SEND and
ACTION_SEND_MULTIPLE for application/pdf add **Share to Cave Paper**. Storage-wide
access exists only for the opt-in device list, granted by the person in Android settings.

The iOS UIScene/AppDelegate implementation and bounded coordinated imports are
documented in IOS_OPEN_IN.md. The iOS simulator adapter compiles; physical-device/Open In acceptance is still pending. Android build qualification is still pending. Dart protocol tests cover queued cold paths and warm
open delivery; they do not establish native platform correctness.

Approved art is integrated into the Flutter interface; platform icon resources
are packaged, with native installation/icon-cache checks still pending. Windows/Linux source handlers now use single-instance forwarding; native compilation and runtime checks remain pending.

## Platform qualification matrix (2026-11-17)

| Target | Registration evidence | Remaining gate |
| --- | --- | --- |
| macOS | Actual LaunchServices PDF Viewer/Alternate claim and document icon; release build passes | Installed cold/warm Open With and signing/notarization qualification |
| iOS | PDF Viewer/Alternate plist, scene adapter, simulator build passes | Files/provider cold/warm Open In on device; no universal default-reader claim |
| Android | file/content PDF VIEW filter, singleTop; PDF-only SEND/SEND_MULTIPLE; no network permission; All files access only for the opt-in device list | APK build and device intent/chooser acceptance |
| Windows | Source argument/IPC adapter and per-user installer registration | Per-user installer ProgID/OpenWith source added; Inno compile, install/uninstall and native tests pending |
| Linux | application/pdf desktop-entry template and GApplication adapter | Desktop entry installation, native build/session-bus tests |

Tests assert Apple Viewer/Alternate metadata, Android PDF-only local intents, no
network or write permission, and Linux file-argument desktop entry. These are
regression guards, not substitutes for installation and OS chooser tests.

