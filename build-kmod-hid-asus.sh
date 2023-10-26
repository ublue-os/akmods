#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD hid-asus (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-hid-asus-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod hid-asus
modinfo /usr/lib/modules/${KERNEL}/extra/hid-asus/hid-asus.ko.xz > /dev/null \
|| (find /var/cache/akmods/hid-asus/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
