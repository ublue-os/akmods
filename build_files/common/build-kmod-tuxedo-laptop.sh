#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

curl -LsSf -o /etc/yum.repos.d/_copr_gladion136-tuxedo-drivers-kmod.repo "https://copr.fedorainfracloud.org/coprs/gladion136/tuxedo-drivers-kmod/repo/fedora-${RELEASE}/gladion136-tuxedo-drivers-kmod-fedora-${RELEASE}.repo"

### BUILD tuxedo-drivers (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-tuxedo-drivers-*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod tuxedo-drivers
for module in /usr/lib/modules/${KERNEL}/extra/tuxedo-drivers/*.ko.xz; do
    modinfo "$module" > /dev/null \
    || (find /var/cache/akmods/tuxedo-drivers/ -name \*.log -print -exec cat {} \; && exit 1)
done

rm -f /etc/yum.repos.d/_copr_gladion136-tuxedo-drivers-kmod.repo
