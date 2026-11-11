#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

KERNEL="$1"
module="$2"
PUBLIC_CERT="$3"
extractor="${4:-/usr/src/kernels/${KERNEL}/scripts/extract-module-sig.pl}"

signers=$(mktemp -d)
trap 'rm -rf "$signers"' EXIT
kmod_sig="$signers/kmod.sig"
kmod_p7s="$signers/kmod.p7s"
kmod_data="$signers/kmod.data"
"$extractor" -s "${module}" > "${kmod_sig}"
openssl pkcs7 -inform der -in "${kmod_sig}" -out "${kmod_p7s}"
"$extractor" -0 "${module}" > "${kmod_data}"
if openssl cms -verify -binary -inform PEM \
    -in "${kmod_p7s}" \
    -content "${kmod_data}" \
    -certfile "${PUBLIC_CERT}" \
    -out "/dev/null" \
    -signer "$signers/verified.pem" \
    -nointern -noverify
    then
    echo "Signature Verified for ${module}"
else
    echo "Signature Failed for ${module}"
    exit 1
fi

# CMS verifies all signatures above. Require every configured certificate to
# occur among the verified signers, not just in the supplied certificate bundle.
split_certs() {
    awk -v directory="$2" '
        /-----BEGIN CERTIFICATE-----/ { n++; file = directory "/" n ".pem" }
        file != "" { print > file }
        /-----END CERTIFICATE-----/ { close(file); file = "" }
    ' "$1"
}
mkdir "$signers/expected" "$signers/actual"
split_certs "$PUBLIC_CERT" "$signers/expected"
split_certs "$signers/verified.pem" "$signers/actual"
for cert in "$signers/actual"/*.pem; do
    openssl x509 -in "$cert" -noout -fingerprint -sha256
done > "$signers/fingerprints"
for cert in "$signers/expected"/*.pem; do
    fingerprint=$(openssl x509 -in "$cert" -noout -fingerprint -sha256)
    grep -Fxq "$fingerprint" "$signers/fingerprints" || {
        echo "Missing expected signer in $module: $fingerprint" >&2
        exit 1
    }
done
