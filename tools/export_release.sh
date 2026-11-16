#!/usr/bin/env bash
# Builds the signed release files:
#   build/puzzloom-release.aab  -> upload to Google Play
#   build/puzzloom-release.apk  -> install on your own phone
#
#   GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/export_release.sh
#
# The key and its password live ONLY in this project's keys/ folder
# (ignored by git). Back that folder up in 3 safe places.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
KEYSTORE="keys/puzzloom-release.keystore"
PASS_FILE="keys/puzzloom-release.pass"
ALIAS="puzzloom"

[ -f "$KEYSTORE" ] && [ -f "$PASS_FILE" ] || { echo "Missing $KEYSTORE or $PASS_FILE"; exit 1; }
command -v "$GODOT" >/dev/null 2>&1 || [ -x "$GODOT" ] || { echo "Godot not found: set GODOT=/path/to/godot"; exit 1; }

mkdir -p build
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$PASS_FILE")"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

"$GODOT" --headless --path . --install-android-build-template \
	--export-release "Android Release" build/puzzloom-release.aab
"$GODOT" --headless --path . --export-release "Android" build/puzzloom-release.apk

ls -la build/puzzloom-release.aab build/puzzloom-release.apk
echo "== Done: build/puzzloom-release.aab (Google Play) + build/puzzloom-release.apk (phone)"
