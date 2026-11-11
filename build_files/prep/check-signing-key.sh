#!/usr/bin/env bash

# Compare public keys rather than certificate metadata or private key encodings.
check_signing_key() (
    set -o pipefail
    local key="$1" cert="$2" key_digest cert_digest

    if [[ ! -s "$key" || ! -s "$cert" ]]; then
        echo "Missing signing key or certificate: $key $cert" >&2
        return 1
    fi
    key_digest=$(openssl pkey -in "$key" -pubout -outform DER 2>/dev/null | sha256sum) || return 1
    cert_digest=$(openssl x509 -in "$cert" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum) || return 1
    if [[ "$key_digest" != "$cert_digest" ]]; then
        echo "Signing key does not match certificate: $key $cert" >&2
        return 1
    fi
)

# Resolve one explicitly selected key set. Never fall back from production to tests.
load_signing_keys() {
    local cert_dir="$1" mode="$2" list id
    case "$mode" in
        production|test) list="$cert_dir/$mode/signing-keys" ;;
        *) echo "Unknown signing mode: $mode" >&2; return 1 ;;
    esac
    [[ -s "$list" ]] || { echo "Empty or missing key list: $list" >&2; return 1; }
    KSIGN_IDS=()
    while IFS= read -r id || [[ -n "$id" ]]; do
        [[ "$id" =~ ^KSIGN_[A-Z0-9_]+$ ]] || { echo "Invalid signing key ID: $id" >&2; return 1; }
        [[ " ${KSIGN_IDS[*]} " != *" $id "* ]] || { echo "Duplicate signing key ID: $id" >&2; return 1; }
        KSIGN_IDS+=("$id")
    done < "$list"
    # Used by callers of this sourced function.
    # shellcheck disable=SC2034
    KSIGN_DIR="$cert_dir/$mode"
}

signing_key_digest() (
    set -euo pipefail
    load_signing_keys "$1" "$2"
    for id in "${KSIGN_IDS[@]}"; do
        printf '%s\n' "$id"
        openssl x509 -in "$KSIGN_DIR/$id.der" -outform DER | sha256sum
    done | sha256sum | cut -d' ' -f1
)
