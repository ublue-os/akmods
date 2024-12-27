#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD gpd-fan (succeed or fail-fast with debug output)
dnf install -y \
    akmod-gpd-fan-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod gpd-fan
modinfo /usr/lib/modules/${KERNEL}/extra/gpd-fan/gpd-fan.ko.xz > /dev/null \
|| (find /var/cache/akmods/gpd-fan/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
