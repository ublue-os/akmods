#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
mapfile -t KSIGN_IDS < /tmp/certs/active-signing-keys
signers=()
for id in "${KSIGN_IDS[@]}"; do
    signers+=(-signer "/tmp/certs/$id.pem")
done
PUBLIC_CHAIN="/tmp/certs/signing-chain.pem"

for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*; do
    module_basename=${module:0:-3}
    module_suffix=${module: -3}
    if [[ "$module_suffix" == ".xz" ]]; then
        xz --decompress "$module"
        openssl cms -sign "${signers[@]}" -binary -in "$module_basename" -outform DER -out "${module_basename}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module_basename}.cms" sha256 "${PUBLIC_CHAIN}" "${module_basename}"
        /tmp/check-module-signature.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
        xz -C crc32 -f "${module_basename}"
    elif [[ "$module_suffix" == ".gz" ]]; then
        gzip -d "$module"
        openssl cms -sign "${signers[@]}" -binary -in "$module_basename" -outform DER -out "${module_basename}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module_basename}.cms" sha256 "${PUBLIC_CHAIN}" "${module_basename}"
        /tmp/check-module-signature.sh "${KERNEL}" "${module_basename}" "${PUBLIC_CHAIN}"
        gzip -9f "${module_basename}"
    else
        openssl cms -sign "${signers[@]}" -binary -in "$module" -outform DER -out "${module}.cms" -nocerts -noattr -nosmimecap
        /usr/src/kernels/"${KERNEL}"/scripts/sign-file -s "${module}.cms" sha256 "${PUBLIC_CHAIN}" "${module}"
        /tmp/check-module-signature.sh "${KERNEL}" "${module}" "${PUBLIC_CHAIN}"
    fi
done
find /var/cache/akmods -type f -name "\kmod-*.rpm"
pushd /var/cache/akmods
mapfile -t RPMPATHS < <(find . -type f -name "\kmod-*.rpm")
for RPMPATH in "${RPMPATHS[@]}"; do
    RPM=$(basename "${RPMPATH/\.rpm/}")
    mkdir -p /tmp/buildroot
    cp -r /{usr,lib} /tmp/buildroot
    rpmrebuild --notest-install --additional=--buildroot=/tmp/buildroot --batch "$RPM"
    rm -rf /tmp/buildroot
done
popd
rm -rf /usr/lib/modules/"${KERNEL}"/extra

# on some kernels, akmods/rpmbuild seems to mangle kernel version in the kmod package name
pushd /root/rpmbuild/RPMS/"$(uname -m)"/
mapfile -t RPMPATHS < <(find . -type f -name "\kmod-*.rpm")
for RPMPATH in "${RPMPATHS[@]}"; do
    RPM=$(basename "${RPMPATH/\.rpm/}")
    if [[ ! "$RPM" =~ ${KERNEL} ]]; then
        RENAME=${RPM%"$(rpm -q --queryformat="%{VERSION}" kernel)"*}
        RENAME+=$KERNEL
        RENAME+=${RPM#*"$(rpm -E %dist)"}
        RPM_RENAME="$(dirname "$RPMPATH")/$RENAME.rpm"
        mv "$RPMPATH" "$RPM_RENAME"
    fi
done
# Reinstall KMODs for initial check that they were signed
mapfile -t kmods < <(ls -1 ./kmod-*.rpm)
dnf reinstall -y --allowerasing "${kmods[@]}"
popd
for module in /usr/lib/modules/"${KERNEL}"/extra/*/*.ko*; do
    if ! modinfo "${module}" >/dev/null; then
        exit 1
    fi
done
