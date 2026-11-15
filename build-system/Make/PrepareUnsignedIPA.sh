#!/usr/bin/env bash
set -euo pipefail

INPUT_IPA="${1:?Usage: PrepareUnsignedIPA.sh input.ipa output.ipa}"
OUTPUT_IPA="${2:?Usage: PrepareUnsignedIPA.sh input.ipa output.ipa}"
OUTPUT_DIR="$(dirname "$OUTPUT_IPA")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_IPA="$(cd "$OUTPUT_DIR" && pwd)/$(basename "$OUTPUT_IPA")"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ditto -x -k "$INPUT_IPA" "$WORK_DIR"
test -d "$WORK_DIR/Payload"

while IFS= read -r -d '' code; do
  codesign --remove-signature "$code" 2>/dev/null || true
done < <(find "$WORK_DIR/Payload" -depth \( -type d \( -name '*.app' -o -name '*.appex' -o -name '*.framework' -o -name '*.xpc' \) -o -type f -name '*.dylib' \) -print0)

find "$WORK_DIR/Payload" -type d -name _CodeSignature -prune -exec rm -rf {} +
find "$WORK_DIR/Payload" -type f -name embedded.mobileprovision -delete

rm -f "$OUTPUT_IPA"
(cd "$WORK_DIR" && zip -qry "$OUTPUT_IPA" Payload)
test -s "$OUTPUT_IPA"
unzip -tq "$OUTPUT_IPA"

VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR" "$VERIFY_DIR"' EXIT
ditto -x -k "$OUTPUT_IPA" "$VERIFY_DIR"
test -d "$VERIFY_DIR/Payload"
if find "$VERIFY_DIR/Payload" \( -type d -name _CodeSignature -o -type f -name embedded.mobileprovision \) -print -quit | grep -q .; then
  echo "::error::Signature data remains in the Sideloadly IPA"
  exit 1
fi
echo "Unsigned IPA validated: $OUTPUT_IPA"
