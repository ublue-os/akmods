#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${KERNEL}" =~ "6.8" ]]; then
  echo "SKIPPED BUILD of rtl8814au: compile failure on kernel 6.8 as of 2024-03-17"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

dnf install -y \
    akmod-rtl8821au-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod rtl8821au
modinfo /usr/lib/modules/${KERNEL}/extra/rtl8821au/rtl8821au.ko.xz > /dev/null \
|| (find /var/cache/akmods/rtl8821au/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
