# navy_encrypt_mobile

> Flutter 3.3.8 (via FVM) with JDK 17

## Project setup

1. Install [FVM](https://fvm.app/) and download the locked toolchain:
   ```bash
   fvm install 3.3.8
   fvm use 3.3.8
   ```
2. Install dependencies with the pinned SDK:
   ```bash
   fvm flutter pub get
   ```
3. Configure the environment secrets by copying the sample file and adjusting to your workspace:
   ```bash
   cp .env.example .env
   # Fill in NAVY_API_BASE_URL, signing credentials, and platform identifiers
   ```
4. (Optional) Regenerate any missing Flutter scaffolding before running:
   ```bash
   fvm flutter create .
   ```

## Environment configuration

The application reads runtime configuration through [`flutter_dotenv`](https://pub.dev/packages/flutter_dotenv).

- `.env` – local overrides for development.
- `.env.example` – template consumed by CI when secrets are absent.
- Required keys:
  - `NAVY_API_BASE_URL`
  - Android signing (`ANDROID_KEYSTORE_*`)
  - iOS signing (`IOS_BUNDLE_IDENTIFIER`, `IOS_TEAM_ID`, and provisioning values supplied through GitHub secrets)
  - Windows publisher metadata

When running in CI, GitHub secrets may provide an `ENV_FILE` blob that replaces `.env` entirely.

## Automated quality gates

This repository ships with automation to protect the encryption workflow on every change.

- **Static analysis** – `flutter analyze`
- **Unit tests** – Dart tests guarding AES helpers (run via `flutter test`)
- **Integration tests** – optional, execute locally before tagging a release

Run the checks locally with FVM:

```bash
fvm flutter analyze
fvm flutter test
```

## Multi-platform build & release pipeline

The release workflow (`.github/workflows/release.yml`) triggers on pushes to `main`, manual dispatch, or semver tags (`v*`). It executes the following matrix:

1. **Lint job (Ubuntu)** – installs Flutter 3.3.8, runs `flutter analyze` and `flutter test`.
2. **Android job (Ubuntu)** – decodes the signing keystore if secrets are present, builds a release APK, and uploads the artifact.
3. **iOS job (macOS)** – configures signing via generated `Signing.xcconfig`, builds an IPA with the enterprise export plist, and uploads the artifact.
4. **Windows job (Windows)** – seeds `.env`, invokes `tools/build_windows.ps1 -BuildMode release`, and archives both the runner and installer output.
5. **Release job (Ubuntu)** – available on tags, aggregates artifacts, renders changelog notes, and publishes a GitHub Release.

Populate the required secrets before pushing tags:

- `ENV_FILE`
- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- iOS: `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_PROVISIONING_PROFILE_SPECIFIER`, `IOS_BUNDLE_IDENTIFIER`, `IOS_TEAM_ID`

## Windows desktop packaging

Use PowerShell to drive the provided script (requires [Inno Setup](https://jrsoftware.org/isinfo.php)):

```powershell
pwsh ./tools/build_windows.ps1 -BuildMode release
```

Artifacts are placed under `build/windows/runner/Release` and `windows_installer/Output`.

## Release management

Releases follow [Semantic Versioning](https://semver.org/) and are documented in [`CHANGELOG.md`](CHANGELOG.md). Tag releases using `v<MAJOR>.<MINOR>.<PATCH>` (for example `v4.2.0`).

1. Update `pubspec.yaml` with the new version.
2. Document the changes in the changelog under the appropriate heading.
3. Commit and push to `main`.
4. Create and push the Git tag (e.g. `git tag v4.2.0 && git push origin v4.2.0`).
5. Let the release workflow upload artifacts and publish notes automatically.

Keep the build metadata (`+<build-number>`) in sync with store submissions when applicable.
