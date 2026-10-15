#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Keep local releases and GitHub/Homebrew artifacts on the same toolchain.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
case "$(xcodebuild -version | head -n 1)" in
  "Xcode 27.0") ;;
  *) echo "Release requires Xcode 27.0 (set DEVELOPER_DIR)." >&2; exit 1 ;;
esac
test "$(xcrun --sdk macosx27.0 --show-sdk-version)" = "27.0"

build_dir="${BLOCT_RELEASE_BUILD_DIR:-$PWD/build/Release}"
xcodegen generate
xcodebuild -project Bloct.xcodeproj -scheme Bloct -configuration Release \
  -sdk macosx27.0 -derivedDataPath "$build_dir/DerivedData" \
  CONFIGURATION_BUILD_DIR="$build_dir" \
  MACOSX_DEPLOYMENT_TARGET=14.0 ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
python3 scripts/verify-release.py "$build_dir/Bloct.app"
