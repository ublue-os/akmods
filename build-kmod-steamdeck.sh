#!/bin/sh

set -oeux pipefail

wget https://copr.fedorainfracloud.org/coprs/kylegospo/steamdeck-kmod/repo/fedora-$(rpm -E %fedora)/kylegospo-steamdeck-kmod-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_kylegospo-steamdeck-kmod.repo

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-steamdeck-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod steamdeck
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck/steamdeck.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_kylegospo-steamdeck-kmod.repo
