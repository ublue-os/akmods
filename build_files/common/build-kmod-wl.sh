#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

DIST="$(rpm -E '%{dist}')"
if [[ "${DIST}" == .el* ]]; then
    # EL: modules come from the distro-matched ublue akmods COPR; skip cleanly until packaged there
    cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/ 2>/dev/null || true
    if [[ -z "$(dnf -q --assumeyes repoquery --available "akmod-wl-*${DIST}.${ARCH}" 2>/dev/null || true)" ]]; then
        echo "SKIPPED: wl (no package for ${DIST})"
        exit 0
    fi
fi

# Skip for aarch64
if [[ "${ARCH}" =~ aarch64 ]]; then
    exit 0
fi


### BUILD wl (succeed or fail-fast with debug output)
dnf install -y \
    akmod-wl-*"${DIST}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/"${KERNEL}"/extra/wl/wl.ko.xz > /dev/null \
|| (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    broadcom-wl

rm -f /var/cache/rpms/common/*.src.rpm
