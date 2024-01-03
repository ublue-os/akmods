#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD zenpower (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-zenpower3-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod zenpower3
modinfo /usr/lib/modules/${KERNEL}/extra/zenpower3/zenpower.ko.xz > /dev/null \
|| (find /var/cache/akmods/zenpower3/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
