#!/usr/bin/env bash
# Linux counterpart of clear_dev_storage.ps1.
# Web: tokens are tied to DEV_AUTH_STORAGE_SESSION, which changes on every launch,
# so a fresh launch already starts logged out; clear the browser tab manually if needed.
target="${1:-all}"
android_package="${ANDROID_PACKAGE:-com.example.eflutter}"

if [[ "$target" == "all" || "$target" == "android" ]]; then
  if ! command -v adb >/dev/null; then
    echo "adb not found; skipped Android storage cleanup."
  elif ! adb devices | grep -q "device$"; then
    echo "No Android device connected; skipped Android storage cleanup."
  else
    adb shell pm clear "$android_package"
  fi
fi

if [[ "$target" == "all" || "$target" == "web" ]]; then
  echo "Web storage cleanup is not automated on Linux; clear site data for localhost:7357 in the browser."
fi
