#!/usr/bin/env bash
set -euo pipefail

# Keep one certificate across rebuilds. A hash-only ad-hoc identity changes
# whenever the executable changes, invalidating Keychain and privacy grants.
APP_BUNDLE="${1:?usage: sign_mac_dev.sh APP_BUNDLE}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY_FILE="${AUGMA_CODESIGN_IDENTITY_FILE:-$ROOT_DIR/apps/mac/.signing-identity.local}"
REQUESTED_IDENTITY="${AUGMA_CODESIGN_IDENTITY:-}"
if [[ -z "$REQUESTED_IDENTITY" && -f "$IDENTITY_FILE" ]]; then
  REQUESTED_IDENTITY="$(cat "$IDENTITY_FILE")"
fi

IDENTITIES="$(security find-identity -v -p codesigning)"
CANDIDATES=()
IDENTITY_PATTERN='[[:space:]]([[:xdigit:]]{40}) "([^"]+)"'
while IFS= read -r line; do
  if [[ "$line" =~ $IDENTITY_PATTERN ]]; then
    fingerprint="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"
    if [[ -n "$REQUESTED_IDENTITY" ]]; then
      if [[ "$REQUESTED_IDENTITY" == "$fingerprint" || "$REQUESTED_IDENTITY" == "$name" ]]; then
        CANDIDATES+=("$fingerprint")
      fi
    elif [[ "$name" == "Apple Development:"* || "$name" == "Mac Developer:"* ]]; then
      CANDIDATES+=("$fingerprint")
    fi
  fi
done <<< "$IDENTITIES"

if [[ ${#CANDIDATES[@]} -ne 1 ]]; then
  echo "A stable local code-signing identity is required; ad-hoc signing is disabled for development." >&2
  echo "Run 'security find-identity -v -p codesigning', then set AUGMA_CODESIGN_IDENTITY to one certificate's SHA-1 or exact name." >&2
  echo "If none is available, create an Apple Development identity in Xcode or a self-signed Code Signing certificate in Keychain Access." >&2
  echo "The selected identity is pinned in $IDENTITY_FILE; replace it explicitly when rotating certificates." >&2
  exit 1
fi

codesign --force --sign "${CANDIDATES[0]}" --identifier cn.yunyoujun.augma.desktop-demo \
  --timestamp=none "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
# Only persist after signing succeeds. No certificate or private key is exported.
umask 077
mkdir -p "$(dirname "$IDENTITY_FILE")"
printf '%s\n' "${CANDIDATES[0]}" > "$IDENTITY_FILE"
echo "Local development signing identity: ${CANDIDATES[0]}"
