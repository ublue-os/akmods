#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

dnf download -y --destdir /var/cache/rpms/akmods \
    akmod-ayn-platform-*.fc${RELEASE}.${ARCH}
dnf install -y \
    /var/cache/rpms/akmods/akmod-ayn-platform-*.rpm
akmods --force --kernels "${KERNEL}" --kmod ayn-platform
modinfo /usr/lib/modules/${KERNEL}/extra/ayn-platform/ayn-platform.ko.xz > /dev/null \
|| (find /var/cache/akmods/ayn-platform/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
