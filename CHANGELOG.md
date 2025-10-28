# Changelog

All notable changes to this project will be documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Downgraded desktop/mobile plugins (`share_plus`, `permission_handler`, `device_info_plus`, `image_picker`, `path_provider`, `file_selector`, `open_filex`, `image_gallery_saver_plus`, `uuid`) to the last versions compatible with the locked Flutter 3.3.8 toolchain so Android, iOS, and Windows builds run again.

## [4.2.0] - 2024-05-28
### Added
- `.fvmrc`, platform signing templates, and environment scaffolding to lock the Flutter 3.3.8 toolchain across contributors.
- GitHub Actions release workflow that builds Android, iOS, and Windows artifacts, uploads them as build outputs, and publishes tagged releases.
- Windows PowerShell automation for packaging the desktop runner via Inno Setup.

### Changed
- Refined `IOHelper` platform guards to respect sandbox/external storage rules and provide safer preview/share flows per platform.
- Updated home page layouts to use `LayoutBuilder` for responsive menu grids on mobile and desktop.
- Centralised API configuration through `.env`/`flutter_dotenv` and refreshed version metadata to `4.2.0+5`.

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

[4.2.0]: https://github.com/your-org/navy_encrypt_mobile/releases/tag/v4.2.0
