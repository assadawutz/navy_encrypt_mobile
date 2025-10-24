# Changelog

All notable changes to this project will be documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.2.0] - 2024-05-18
### Added
- Platform guard that validates storage permissions on Android, sandbox access on iOS,
  and local disk availability on Windows before the UI loads.
- Environment loader that reads from build-time environment variables or
  `--dart-define` values so release credentials and branding stay out of source
  code.
- Windows PowerShell packaging script plus GitHub Actions job that publish a zipped runner.
- Flutter FVM configuration to lock the toolchain to version 3.3.8 across platforms.
- Deterministic Dart script that generates iOS icons/launch images during the build so binary assets stay out of git.

### Changed
- Updated Android signing to read keystore secrets from environment variables or `.env` files instead of hardcoding them.
- Externalised iOS build configuration into checked-in `.xcconfig` files that align with the enterprise export plist.
- Reworked responsive layouts to use `LayoutBuilder`, ensuring desktop and tablet widths render correctly.
- Extended the release workflow to enforce changelog/tag parity and to build Android, iOS, and Windows artifacts in parallel.
- Bumped the application version to `4.2.0+5` for the production-ready release toolchain.
- Removed committed binary artifacts (Windows installer, sample keystore) and
  updated documentation to keep signing materials outside version control.

## [4.1.1] - 2024-05-17
### Added
- Integration tests that exercise `Navec.encryptFile` end-to-end, validating
  header metadata, UUID persistence, and error handling.

### Changed
- Documented the FVM-driven setup workflow and surfaced the new tests in the
  README so contributors can bootstrap the project consistently.
- Bumped the application version to `4.1.1+4` to reflect the additional test coverage.

## [4.1.0] - 2024-05-16
### Added
- Automated unit tests covering AES encryption behaviour.
- GitHub Actions workflow that runs analysis, tests, and a debug build before
  merge.
- Lint configuration via `flutter_lints`.
- Release management documentation and changelog to support tagging strategy.

### Changed
- Bumped application version to `4.1.0+3` in `pubspec.yaml`.

[4.2.0]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.2.0
[4.1.1]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.1.1
[4.1.0]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.1.0
