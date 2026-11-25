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

## On this device (opt-in)

The device list is off until the person opens **On this device**. On Android it
needs All files access, which the person grants in Android's own settings
screen. The scan reads only file names, sizes and dates; it never reads file
contents, follows links, enters hidden folders or other apps' private
`Android/data` and `Android/obb` folders, and its results are kept in memory
only, never saved or sent anywhere. A file is copied into the library only when
the person opens it. Revoke the access in Android settings at any time; the rest
of the app keeps working. On desktop, the list covers Desktop, Documents and
Downloads (Windows/Linux) or folders the person picks in the system dialog.

Library thumbnails are small PNG previews of each imported document's first
page, stored in the `thumbnails` folder of the data directory and deleted with
the document. They can show page content, like the imported copy itself.

Before release, measure runtime traffic with networking disabled, including
missing-font, malicious-link and encrypted-PDF cases on each operating system.
The current source policy has not been verified in a packaged application.
