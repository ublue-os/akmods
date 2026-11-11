#!/usr/bin/env bash

# Never trace secret values, even if a caller enables shell tracing.
set +x
set -euo pipefail
#shellcheck source=build_files/prep/check-signing-key.sh
source "$(dirname "$0")/check-signing-key.sh"
load_signing_keys "${1:-certs}" production

for id in "${KSIGN_IDS[@]}"; do
    [[ -n "${!id:-}" ]] || { echo "Missing signing secret: $id" >&2; exit 1; }
done

umask 077
tmp=''
trap '[[ -z "$tmp" ]] || rm -f "$tmp"' EXIT
for id in "${KSIGN_IDS[@]}"; do
    tmp=$(mktemp "$KSIGN_DIR/.$id.XXXXXX")
    printf '%s\n' "${!id}" > "$tmp"
    check_signing_key "$tmp" "$KSIGN_DIR/$id.der"
    mv -f "$tmp" "$KSIGN_DIR/$id.key"
    tmp=''
done
