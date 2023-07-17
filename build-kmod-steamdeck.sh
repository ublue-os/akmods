#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

wget https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/repo/fedora-${RELEASE}/ublue-os-akmods-fedora-${RELEASE}.repo -O /etc/yum.repos.d/_copr_ublue-os-akmods.repo

rpm-ostree install \
    akmod-steamdeck-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod steamdeck
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck/steamdeck.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
