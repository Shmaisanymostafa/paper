# Synthetic protected PDF fixtures

Both PDFs contain only page 1 of the repository's synthetic `assets/sample.pdf`.
Generated using isolated test-only pypdf 6.1.3 (BSD-3-Clause); no dependency added
to the application. RC4-128 is used only for exercising compatibility/rejection,
not recommended as document security.

- `assembly-restricted.pdf`: empty user password; owner password
  `fixture-owner-only`; permissions flag 0.
- `password-protected.pdf`: user password `fixture-only`; owner password
  `fixture-owner-only`; permissions flag 0.

These public fixture passwords are not credentials. The app must reject both
rather than produce an unprotected copy. The first exercises the encrypted
openable-file branch; the second exercises failure to open without a password.
