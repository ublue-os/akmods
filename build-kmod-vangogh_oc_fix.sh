#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-vangogh_oc_fix-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod vangogh_oc_fix
modinfo /usr/lib/modules/${KERNEL}/extra/vangogh_oc_fix/vangogh_oc_fix.ko.xz > /dev/null \
|| (find /var/cache/akmods/vangogh_oc_fix/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
