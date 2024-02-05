#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-bmi160-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod bmi160
modinfo /usr/lib/modules/${KERNEL}/extra/bmi160/bmi160_{core,i2c,spi}.ko.xz > /dev/null \
|| (find /var/cache/akmods/bmi160/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
