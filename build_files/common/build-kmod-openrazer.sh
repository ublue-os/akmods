#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

DIST="$(rpm -E '%{dist}')"
if [[ "${DIST}" == .el* ]]; then
    # EL: modules come from the distro-matched ublue akmods COPR; skip cleanly until packaged there
    cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/ 2>/dev/null || true
    if [[ -z "$(dnf -q repoquery --available "akmod-openrazer-*${DIST}.${ARCH}" || true)" ]]; then
        echo "SKIPPED: openrazer (no package for ${DIST})"
        exit 0
    fi
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD openrazer (succeed or fail-fast with debug output)
dnf install -y \
    akmod-openrazer-*"${DIST}."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod openrazer
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkbd.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razermouse.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razerkraken.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/openrazer/razeraccessory.ko.xz >/dev/null ||
    (find /var/cache/akmods/openrazer/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    openrazer-kmod-common

rm -f /var/cache/rpms/common/*.src.rpm

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
