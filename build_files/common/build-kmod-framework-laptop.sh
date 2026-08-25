#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

DIST="$(rpm -E '%{dist}')"
if [[ "${DIST}" == .el* ]]; then
    # EL: modules come from the distro-matched ublue akmods COPR; skip cleanly until packaged there
    cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/ 2>/dev/null || true
    if [[ -z "$(dnf -q repoquery --available "akmod-framework-laptop-*${DIST}.${ARCH}" || true)" ]]; then
        echo "SKIPPED: framework-laptop (no package for ${DIST})"
        exit 0
    fi
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD framework-laptop (succeed or fail-fast with debug output)
dnf install -y \
    akmod-framework-laptop-*"${DIST}."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod framework-laptop
modinfo /usr/lib/modules/"${KERNEL}"/extra/framework-laptop/framework_laptop.ko.xz > /dev/null \
|| (find /var/cache/akmods/framework-laptop/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    framework-laptop-kmod-common

rm -f /var/cache/rpms/common/*.src.rpm

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
