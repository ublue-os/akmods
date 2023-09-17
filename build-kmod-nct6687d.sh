#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD nct6687d (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-nct6687d-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod nct6687d
modinfo /usr/lib/modules/${KERNEL}/extra/nct6687d/nct6687.ko.xz > /dev/null \
|| (find /var/cache/akmods/nct6687d/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
