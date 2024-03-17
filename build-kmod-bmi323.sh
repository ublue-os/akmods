#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    akmod-bmi323-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod bmi323
modinfo /usr/lib/modules/${KERNEL}/extra/bmi323/bm{i323_,c150-accel-}{core,i2c,spi}.ko.xz > /dev/null \
|| (find /var/cache/akmods/bmi323/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
