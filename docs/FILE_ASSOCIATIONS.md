# Default PDF viewer / open-with status

macOS source advertises `com.adobe.pdf` as Viewer with Alternate rank. The
native adapter queues cold launches and delivers warm open events. Flutter
imports a validated managed copy before opening it; original files remain unchanged.
Security-scoped access is released after import. Multiple files open sequentially.
The user chooses Finder > Get Info > Open with > Change All, if desired.
The app never changes system defaults automatically.

Current verification: Dart adapter tests and analyzer only. Native cold/warm
launch, multiple-file, denied-file, sandbox and installed-app association tests
remain required. This is not a verified macOS handler release.

Windows and Linux adapters/packaging remain pending; see mobile continuation below. On iOS,
Open In / document import does not imply a universal default PDF reader setting.
On Windows, the selected default application's ProgID controls the PDF file
icon; Cave Paper cannot promise its icon while another app is the default.

Approved app/logo and PDF file-icon originals are preserved separately for
packaging; the platform runner art has not yet been replaced. Do not publish
unapproved substitutions or claim these features shipped.

## Mobile continuation

Android now advertises ACTION_VIEW application/pdf for content/file URIs,
handles initial and subsequent intents, copies off the UI thread with a 200MiB
limit and releases only temporary files it owns. No storage-wide permission.

The iOS UIScene/AppDelegate implementation and bounded coordinated imports are
documented in IOS_OPEN_IN.md. Neither mobile adapter has native build/device
acceptance evidence yet. Dart protocol tests cover queued cold paths and warm
open delivery; they do not establish native platform correctness.

Approved art is integrated into the Flutter interface; platform icon resources
remain pending. Windows/Linux handlers are still pending, including safe
single-instance forwarding so concurrent writers cannot corrupt library state.
