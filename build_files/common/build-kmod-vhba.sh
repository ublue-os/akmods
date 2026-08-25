#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

DIST="$(rpm -E '%{dist}')"
if [[ "${DIST}" == .el* ]]; then
    # EL: modules come from the distro-matched ublue akmods COPR; skip cleanly until packaged there
    cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/ 2>/dev/null || true
    if [[ -z "$(dnf -q repoquery --available "akmod-vhba-*${DIST}.${ARCH}" || true)" ]]; then
        echo "SKIPPED: vhba (no package for ${DIST})"
        exit 0
    fi
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_rok-cdemu.repo /etc/yum.repos.d/

### BUILD vhba (succeed or fail-fast with debug output)
dnf install -y \
    akmod-vhba-*"${DIST}."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod vhba
modinfo /usr/lib/modules/"${KERNEL}"/extra/vhba/vhba.ko.xz > /dev/null \
|| (find /var/cache/akmods/vhba/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    vhba-kmod-common

rm -f /var/cache/rpms/common/*.src.rpm

rm -f /etc/yum.repos.d/_copr_rok-cdemu.repo
