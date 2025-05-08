#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_ethernium-aorus-laptop.repo \
    "https://copr.fedorainfracloud.org/coprs/ethernium/aorus-laptop/repo/fedora-${COPR_RELEASE}/ethernium-aorus-laptop-fedora-${COPR_RELEASE}.repo"

### BUILD aorus-laptop (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-aorus-laptop-*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod aorus-laptop
modinfo "/usr/lib/modules/${KERNEL}/extra/aorus-laptop/aorus-laptop.ko.xz" >/dev/null ||
    (find /var/cache/akmods/aorus-laptop/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ethernium-aorus-laptop.repo