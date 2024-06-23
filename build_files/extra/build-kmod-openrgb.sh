#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    akmod-openrgb-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod openrgb
modinfo /usr/lib/modules/${KERNEL}/extra/openrgb/i2c-{piix4,nct6775}.ko.xz > /dev/null \
|| (find /var/cache/akmods/openrgb/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
