#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

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
modinfo "/usr/lib/modules/${KERNEL}/extra/kvmfr/kvmfr.ko.xz" > /dev/null \
|| (find /var/cache/akmods/kvmfr/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_hikariknight-looking-glass-kvmfr.repo
