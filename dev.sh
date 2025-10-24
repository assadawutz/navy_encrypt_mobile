#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[navy_encrypt_mobile] smoke build (Plan A matrix)"

# DIR: ${ROOT_DIR}   # WHY: ตรวจเวอร์ชัน Flutter ผ่าน FVM
fvm flutter --version

# DIR: ${ROOT_DIR}   # WHY: ล้าง build เก่า
fvm flutter clean

# DIR: ${ROOT_DIR}   # WHY: ดึง dependency
fvm flutter pub get

pushd "${ROOT_DIR}/ios" >/dev/null
# DIR: ${ROOT_DIR}/ios   # WHY: ติดตั้ง CocoaPods
pod install
popd >/dev/null

# DIR: ${ROOT_DIR}   # WHY: วิเคราะห์โค้ด
fvm flutter analyze

# DIR: ${ROOT_DIR}   # WHY: รัน unit test
fvm flutter test

# DIR: ${ROOT_DIR}   # WHY: Build iOS simulator
fvm flutter build ios --simulator --no-codesign

# DIR: ${ROOT_DIR}   # WHY: Build Android release APK
fvm flutter build apk --release

# DIR: ${ROOT_DIR}   # WHY: Build Windows debug bundle
fvm flutter build windows
