#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_grandpares-it87-extras.repo "https://copr.fedorainfracloud.org/coprs/grandpares/it87-extras/repo/fedora-${COPR_RELEASE}/grandpares-it87-extras--fedora-${COPR_RELEASE}.repo"

### BUILD it87-extras (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-it87-extras-*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod it87-extras
modinfo "/usr/lib/modules/${KERNEL}/extra/it87-extras/it87-extras.ko.xz" > /dev/null \
|| (find /var/cache/akmods/it87-extras/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_grandpares-it87-extras.repo
