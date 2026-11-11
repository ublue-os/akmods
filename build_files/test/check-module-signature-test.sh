#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Supply an extractor fixture so this test needs no kernel-devel RPM. Real CMS
# signatures and certificates still pass through the production verifier.
cat > "$tmp/extract" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -s ]]; then cat "$2.sig"; else cat "$2"; fi
EOF
chmod +x "$tmp/extract"
printf 'module payload\n' > "$tmp/module"
signers=()
source build_files/prep/check-signing-key.sh
load_signing_keys certs test
for id in "${KSIGN_IDS[@]}"; do
    openssl x509 -in "$KSIGN_DIR/$id.der" -out "$tmp/$id.crt"
    cat "$KSIGN_DIR/$id.key" "$tmp/$id.crt" > "$tmp/$id.pem"
    signers+=(-signer "$tmp/$id.pem")
done
cat "$tmp"/*.crt > "$tmp/chain.pem"
openssl cms -sign "${signers[@]}" -binary -in "$tmp/module" \
    -outform DER -out "$tmp/module.sig" -nocerts -noattr -nosmimecap
bash build_files/prep/check-module-signature.sh fixture "$tmp/module" "$tmp/chain.pem" "$tmp/extract"
# A valid signature by only one key must not satisfy a two-key policy.
openssl cms -sign -signer "$tmp/${KSIGN_IDS[0]}.pem" \
    -binary -in "$tmp/module" -outform DER -out "$tmp/module.sig" -nocerts -noattr -nosmimecap
bash build_files/prep/check-module-signature.sh fixture "$tmp/module" "$tmp/${KSIGN_IDS[0]}.crt" "$tmp/extract"
if bash build_files/prep/check-module-signature.sh fixture "$tmp/module" "$tmp/chain.pem" "$tmp/extract"; then
    echo 'Missing signer accepted' >&2
    exit 1
fi
printf 'tampered\n' >> "$tmp/module"
if bash build_files/prep/check-module-signature.sh fixture "$tmp/module" "$tmp/chain.pem" "$tmp/extract"; then
    echo 'Tampered module accepted' >&2
    exit 1
fi
echo 'Module signature validation passed'
