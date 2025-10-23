# Changelog

All notable changes to this project will be documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[4.1.1]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.1.1
[4.1.0]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.1.0
