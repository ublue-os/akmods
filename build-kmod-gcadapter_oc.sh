#!/bin/sh

set -oeux pipefail

wget https://copr.fedorainfracloud.org/coprs/kylegospo/gcadapter_oc-dkms/repo/fedora-$(rpm -E %fedora)/kylegospo-gcadapter_oc-dkms-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_kylegospo-gcadapter_oc-dkms.repo

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-gcadapter_oc-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod gcadapter_oc
modinfo /usr/lib/modules/${KERNEL}/extra/gcadapter_oc/gcadapter_oc.ko.xz > /dev/null \
|| (find /var/cache/akmods/gcadapter_oc/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_kylegospo-gcadapter_oc-dkms.repo
