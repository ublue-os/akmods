#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/../.."
source build_files/prep/check-signing-key.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/production"
cp certs/test/signing-keys certs/test/*.der "$tmp/production/"
load_signing_keys certs test
for id in "${KSIGN_IDS[@]}"; do unset "$id"; done
if bash build_files/prep/write-signing-keys.sh "$tmp"; then
    echo 'Missing secret accepted' >&2
    exit 1
fi
for id in "${KSIGN_IDS[@]}"; do
    value=$(cat "$KSIGN_DIR/$id.key")
    export "$id=$value"
done
bash build_files/prep/write-signing-keys.sh "$tmp"
for id in "${KSIGN_IDS[@]}"; do
    cmp "$KSIGN_DIR/$id.key" "$tmp/production/$id.key"
    [[ $(stat -c %a "$tmp/production/$id.key") == 600 ]]
done
value=$(cat "$KSIGN_DIR/${KSIGN_IDS[1]}.key")
export "${KSIGN_IDS[0]}=$value"
if bash build_files/prep/write-signing-keys.sh "$tmp"; then
    echo 'Mismatched secret accepted' >&2
    exit 1
fi
echo 'Signing key writer validation passed'
