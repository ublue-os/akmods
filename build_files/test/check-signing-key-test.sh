#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/../.."

#shellcheck source=build_files/prep/check-signing-key.sh
source build_files/prep/check-signing-key.sh

empty_key=$(mktemp)
trap 'rm -f "$empty_key"' EXIT

compat_key=$(cat certs/production/compat-key)
[[ "$compat_key" =~ ^KSIGN_[A-Z0-9_]+$ ]]
cmp certs/public_key.der "certs/production/$compat_key.der"
load_signing_keys certs production
for id in "${KSIGN_IDS[@]}"; do
    openssl x509 -in "$KSIGN_DIR/$id.der" -noout
done
load_signing_keys certs test
[[ ${KSIGN_IDS[*]} == "KSIGN_TEST_A KSIGN_TEST_B" ]]
for id in "${KSIGN_IDS[@]}"; do
    check_signing_key "$KSIGN_DIR/$id.key" "$KSIGN_DIR/$id.der"
done
[[ $(signing_key_digest certs production) != "$(signing_key_digest certs test)" ]]

if check_signing_key certs/test/KSIGN_TEST_A.key certs/test/KSIGN_TEST_B.der; then
    echo 'Mismatched key accepted' >&2
    exit 1
fi
if check_signing_key "$empty_key" certs/public_key.der; then
    echo 'Empty key accepted' >&2
    exit 1
fi
if check_signing_key certs/public_key.der certs/public_key.der; then
    echo 'Invalid private key accepted' >&2
    exit 1
fi

echo 'Signing key validation passed'
