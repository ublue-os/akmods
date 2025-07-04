#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD openrazer (succeed or fail-fast with debug output)
dnf install -y \
    akmod-openrazer-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod openrazer
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkbd.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razermouse.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkraken.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razeraccessory.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
