# Offline privacy

Cave Paper's design has no account, server, telemetry, advertising, crash upload
or update-check service. Imported PDF copies, titles, last page, bookmarks,
notes, highlights, settings and damaged-copy evidence live only in its data
directory. Their retention is under the device owner's control. No automatic
upload/synchronization is implemented.

The selected document password is passed to the renderer only and not persisted.
Clipboard writes happen only when the person presses Copy. Other software and
clipboard history may read that copied content. PDFs can contain sensitive text,
malformed content and external links: keep the native renderer current. The app
does not launch external links or expose JavaScript controls.

This is not an encrypted vault. OS backups or a cloud-synced OS data directory
can copy local files independently of the app. Remove from library removes the
managed document and its active metadata, not the original picked file, OS
backups or secure disk remnants. Back up the app-data directory with the app
closed and test restoration before relying on it.

Before release, measure runtime traffic with networking disabled, including
missing-font, malicious-link and encrypted-PDF cases on each operating system.
The current source policy has not been verified in a packaged application.
