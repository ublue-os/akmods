#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [ "40" == "${RELEASE}" ]; then
  echo "SKIPPED BUILD of gasket: compile failure on F40 as of 2024-03-17"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    akmod-gasket-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod gasket
modinfo /usr/lib/modules/${KERNEL}/extra/gasket/{gasket,apex}.ko.xz > /dev/null \
|| (find /var/cache/akmods/gasket/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
