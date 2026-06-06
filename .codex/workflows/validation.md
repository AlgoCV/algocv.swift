# Validation

Choose validation based on the changed surface area.

- SwiftUI app changes: use Xcode diagnostics for touched Swift files when
  possible, then build the app target with Xcode for compile and integration
  coverage.
- `ImageProModel` changes: run the package tests when the affected code is
  covered there. Also build the app when public model APIs used by SwiftUI have
  changed.
- `ImPro` changes: run the package tests or smoke tests that exercise the native
  bridge, then build dependent model/app targets if Swift API shape changed.
- Document persistence or DTO changes: include serialization-focused tests or a
  full app build, because failures often cross package boundaries.
- Documentation-only or agent-guidance changes: no build is required. Verify
  paths and links by reading the changed Markdown.

Prefer local Xcode tools for app builds and diagnostics when running from Xcode.
Use command-line Swift package commands only when they are the narrower and more
appropriate validation for a package-only change.
