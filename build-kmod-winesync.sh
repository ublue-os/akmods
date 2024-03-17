#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD winesync (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-winesync-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod winesync
modinfo /usr/lib/modules/${KERNEL}/extra/winesync/winesync.ko.xz > /dev/null \
|| (find /var/cache/akmods/winesync/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
