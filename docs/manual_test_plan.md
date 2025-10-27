# Navy Encrypt Mobile – Manual QA Checklist

This checklist focuses on the debug build experience for Android, iOS, and Windows so the core flow (pick → guard → encrypt/decrypt → result) stays functional before release signing is introduced.

## Prerequisites

- Toolchain locked via FVM (`3.3.8`) and Dart `2.18.x`.
- `.env` or `.env.example` copied into the project root.
- Test files that cover every supported extension (`.pdf`, `.docx`, `.pptx`, `.xlsx`, `.txt`, `.jpg`, `.mp4`, `.mp3`, `.zip`, `.enc`).
- For Android devices on API 30+, confirm permission prompts are shown when accessing storage or the camera.

## Android (Debug APK)

1. Build: `fvm flutter build apk --debug` and install on a physical device (API 29–34).
2. Launch and sign in if required; confirm first-run settings dialog opens once.
3. Tap **ไฟล์ในเครื่อง** → pick from "System Dialog". Validate unsupported extensions trigger an error dialog.
4. Pick from "App's Documents Folder" and ensure the workspace contains previously processed files.
5. Test **คลังภาพ** to pull a gallery photo. Confirm permission is requested once and the preview proceeds to Encrypt or Decrypt as expected.
6. Test **กล้อง** (ภาพนิ่งและวิดีโอ). Deny permission once to ensure snackbars show an error, then allow and verify capture.
7. Import a `.enc` file and confirm it routes to the Decrypt page; import any other file and confirm the Encrypt page opens.
8. Complete an encrypt + decrypt cycle and verify the Result page allows Preview, Save, and Share (Share should invoke the Android share sheet).
9. Validate Google Drive / OneDrive flows launch sign-in and list directories (smoke test credentials).

## iOS (Debug, no codesign)

1. Build: `fvm flutter build ios --debug --no-codesign` and open the generated Xcode workspace.
2. Run on a simulator (iOS 15+) and a device if available.
3. On first run, ensure permission prompts appear when tapping **คลังภาพ** or **กล้อง**; denying should show localized snackbar errors.
4. Use the file picker to import each supported extension (Document Picker). Confirm `.enc` routes to Decrypt.
5. Encrypt a standard file and confirm watermark steps complete, then open the Result page and use Preview/Share (ShareSheet should appear).
6. Trigger share intent from Files app into Navy Encrypt and confirm `handleIntent` processes the incoming file.

## Windows (Debug Runner)

1. Build: `flutter build windows --debug` (native Windows install) and run `build\windows\runner\Debug\navy_encrypt_mobile.exe`.
2. Navigate through **ไฟล์ในเครื่อง** → App's folder to confirm workspace/result directories exist under `%USERPROFILE%\Downloads` fallback.
3. Use **System Dialog** to import local files and make sure unsupported extensions raise modal errors.
4. Run an encrypt cycle and confirm the Result page opens File Explorer (`explorer /select, <file>`).
5. Validate OneDrive picker launches OAuth (requires developer credentials) and lists drive contents.
6. Confirm camera options are disabled with explanatory snackbars.

## Regression sweep

Perform the following quick checks on every platform after significant changes:

- Reject a file >20 MB and confirm the size snackbar appears.
- Attempt to process a file without an extension and ensure the error dialog displays.
- Simulate permission denial (storage/photo/camera) and confirm the guard methods block the flow with a snackbar.
- Execute share intent from another application and verify the Home page handles it.

Document any failures alongside reproduction steps before merging into `main`.
