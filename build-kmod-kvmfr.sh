#!/usr/bin/bash

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo "https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/repo/fedora-${COPR_RELEASE}/hikariknight-looking-glass-kvmfr-fedora-${COPR_RELEASE}.repo"

### BUILD kvmfr (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-kvmfr-*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod kvmfr
if ! modinfo "/usr/lib/modules/${KERNEL}/extra/kvmfr/kvmfr.ko.xz" > /dev/null; then
    (find /var/cache/akmods/kvmfr/ -name \*.log -print -exec cat {} \; && exit 1)
fi

if [[ "${DUAL_SIGN}" == "true" ]]; then
    PUBLIC_KEY_PATH_2="/tmp/certs/public_key_2.crt"
    PRIVATE_KEY_PATH_2="/tmp/certs/private_key_2.priv"
    for module in /usr/lib/modules/"${KERNEL}"/extra/kvmfr/*.ko*;
    do
        module_basename=${module:0:-3}
        module_suffix=${module: -3}
        if [[ "$module_suffix" == ".xz" ]]; then
                xz --decompress "$module"
                /usr/src/kernels/"${KERNEL}"/scripts/sign-file sha256 "${PRIVATE_KEY_PATH_2}" "${PUBLIC_KEY_PATH_2}" "${module_basename}"
                xz -f "${module_basename}"
                modinfo "${module}"
        elif [[ "$module_suffix" == ".gz" ]]; then
                gzip -d "$module"
                /usr/src/kernels/"${KERNEL}"/scripts/sign-file sha256 "${PRIVATE_KEY_PATH_2}" "${PUBLIC_KEY_PATH_2}" "${module_basename}"
                gzip -9f "${module_basename}"
                modinfo "${module}"
        else
                /usr/src/kernels/"${KERNEL}"/scripts/sign-file sha256 "${PRIVATE_KEY_PATH_2}" "${PUBLIC_KEY_PATH_2}" "${module_basename}"
                modinfo "${module}"
        fi
    done
fi

if [[ "${DUAL_SIGN}" == "true" ]]; then
    rpmrebuild --batch kmod-kvmfr-"${KERNEL}"-*
    dnf reinstall -y /root/rpmbuild/RPMS/"$(uname -m)"/kmod-kvmfr-"${KERNEL}"-*.rpm
    if ! modinfo "/usr/lib/modules/${KERNEL}/extra/kvmfr/kvmfr.ko.xz" > /dev/null; then
        (find /var/cache/akmods/kvmfr/ -name \*.log -print -exec cat {} \; && exit 1)
    fi
fi

rm -f /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo
