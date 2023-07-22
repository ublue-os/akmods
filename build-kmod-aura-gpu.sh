#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-aura-gpu-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod aura-gpu
modinfo /usr/lib/modules/${KERNEL}/extra/aura-gpu/aura-gpu.ko.xz > /dev/null \
|| (find /var/cache/akmods/aura-gpu/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
