# Security

## Supported versions

There is no qualified binary release or supported release series yet. Security
fixes are developed on `main`; old commits and experimental builds may retain
known problems. The version in `pubspec.yaml` is a candidate identifier, not proof
of a published or accepted release.

The app processes untrusted PDF content using a native renderer. A file picker,
size limit and offline operation do not make malformed PDFs safe. Native renderer
advisories and exact packaged versions must be reviewed before each release.

## Private reporting

Report vulnerabilities to info@cave.technology with a minimal synthetic sample
where possible. Do not upload personal PDFs, passwords or credentials to public
issues. Include the affected commit/version, OS, reproducible steps, expected
impact and a minimal synthetic sample if needed. Do not send real customer data,
stored library folders, signing keys or device secrets.

Allow the maintainer to reproduce and address a report before public disclosure.
No response deadline or bounty program is promised. Use public issues for
ordinary bugs without security-sensitive details.
