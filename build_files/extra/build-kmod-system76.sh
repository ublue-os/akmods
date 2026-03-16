#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_ssweeny-system76-hwe.repo \
    "https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/repo/fedora-${COPR_RELEASE}/ssweeny-system76-hwe-fedora-${COPR_RELEASE}.repo"

### BUILD system76 (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-system76-driver*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod system76-driver
modinfo "/usr/lib/modules/${KERNEL}/extra/system76-driver/system76.ko.xz" > /dev/null \
|| (find /var/cache/akmods/system76-driver/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    system76-driver

rm -f /var/cache/rpms/extra/*.src.rpm

rm -f /etc/yum.repos.d/_copr_ssweeny-system76-hwe.repo
