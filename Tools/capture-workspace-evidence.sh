#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 2 || ! -x .build/claw-workspace-screenshot-check ]]; then
  echo "workspace_capture_invalid_configuration"
  exit 1
fi

simulator_udid="$1"
screenshot_path="$2"

# Keep only the latest frame; a successful launch is not proof of rendered content.
for ((attempt = 1; attempt <= 15; attempt++)); do
  xcrun simctl io "$simulator_udid" screenshot "$screenshot_path"
  if .build/claw-workspace-screenshot-check "$screenshot_path"; then
    printf '{"policy":"claw-mission-ocr-v1","outcome":"success","attempt":%d}\n' "$attempt" > "${screenshot_path%.png}.json"
    echo "workspace_capture_ready attempt=$attempt"
    exit 0
  else
    status="$?"
  fi
  if [[ "$status" -ne 2 ]]; then
    echo "workspace_capture_validator_failed"
    exit 1
  fi
  if [[ "$attempt" -lt 15 ]]; then
    sleep 2
  fi
done

echo "workspace_capture_render_deadline_exceeded"
exit 1
