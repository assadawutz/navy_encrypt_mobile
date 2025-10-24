# navy_encrypt_mobile

> Flutter 3.3.8 (via FVM) with JDK 17

## Project setup

1. Install [FVM](https://fvm.app/) and download the toolchain used in production:
   ```bash
   fvm install 3.3.8
   fvm use 3.3.8
   ```
2. (Re)generate any missing Flutter scaffolding, such as platform folders, before
   running the app:
   ```bash
   fvm flutter create .
   ```
3. Install dependencies with the pinned SDK:
   ```bash
   fvm flutter pub get
   ```

## Configuration and secrets

1. Copy `.env.example` to `.env` and replace each value with production-ready
   secrets. The file is consumed only by native build tooling (Gradle,
   PowerShell, etc.) and **must not** be bundled with the Flutter application.
   Pass runtime configuration such as `APP_DISPLAY_NAME` via
   `--dart-define=KEY=VALUE` when invoking `flutter run`/`flutter build` or by
   exporting real environment variables on desktop builds.
2. Provide a signing keystore when creating release builds:
   - **CI** – Add `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
     `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` secrets. The workflow
     decodes the keystore and wires the Gradle properties automatically.
   - **Local** – Export the same secrets as environment variables or update the
     `.env` file with the keystore path/passwords. The default sample points to
     `../secrets/navy_release.keystore`, which resolves to a sibling directory
     outside of version control.
3. Runtime configuration for the Flutter app should be provided via
   `--dart-define` flags. Encode a newline-delimited env file containing
   **non-sensitive** values and pass it through `APP_CONFIG_BASE64`:
   ```bash
   base64_env=$(base64 -w0 runtime.env) # Use `base64 | tr -d '\n'` on macOS
   fvm flutter run \
     --dart-define=APP_CONFIG_BASE64=$base64_env
   ```
   The loader decodes the string on startup and exposes the values through
   `EnvConfig`. Omit the flag to fall back to hardcoded defaults.
3. Windows release archives are generated with
   `windows/scripts/package_release.ps1`, which bundles the runner output into a
   portable ZIP without tracking binaries in git.
4. ก่อน build iOS ให้สร้าง asset ด้วยสคริปต์:
   ```bash
   fvm flutter pub run tool/generate_apple_assets.dart
   ```
   ถ้าเครื่องไม่มี FVM ให้ใช้ `flutter pub run ...` ตรง ๆ ก็ได้
   (ทางเลือกสำรองคือรันบน macOS CI แล้วดึง asset ที่ workflow สร้างให้).

## Automated quality gates

This repository ships with a comprehensive automation suite to protect the
cryptographic workflow on every change.

- **Static analysis** – `flutter analyze` runs on every push or pull request.
- **Unit tests** – cover AES behaviour and the algorithm registry.
- **Integration tests** – exercise file encryption end-to-end, including NAVEC
  headers and UUID metadata handling.
- **Build verification** – the CI pipeline assembles a debug Android APK to
  catch integration issues early.

Run the checks locally with FVM:

```bash
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

## Continuous integration

The CI workflow (`.github/workflows/ci.yml`) blocks merges unless all quality
checks succeed. It provisions Flutter 3.3.8, restores dependencies, runs
analysis and tests, then builds the Android debug artifact. Extend the workflow
with additional jobs as new platforms are introduced.

## Release management

Releases follow [Semantic Versioning](https://semver.org/) and are documented in
[`CHANGELOG.md`](CHANGELOG.md). Tag releases using the pattern
`v<MAJOR>.<MINOR>.<PATCH>` (for example `v4.1.1`). The workflow is:

1. Update `pubspec.yaml` with the new version.
2. Document the changes in `CHANGELOG.md` under a new heading.
3. Commit and push the changes on the `main` branch.
4. Create a Git tag that matches the version (e.g. `git tag v4.1.1`).
5. Publish release notes using the changelog entry.

Keep the build metadata (`+<build-number>`) in sync with mobile store releases
when applicable.
