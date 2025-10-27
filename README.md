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

