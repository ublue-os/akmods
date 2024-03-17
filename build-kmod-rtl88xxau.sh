#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [ "40" == "${RELEASE}" ]; then
  echo "SKIPPED BUILD of rtl88xxau: compile failure on F40 as of 2024-03-17"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    akmod-rtl88xxau-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod rtl88xxau
modinfo /usr/lib/modules/${KERNEL}/extra/rtl88xxau/88XXau.ko.xz > /dev/null \
|| (find /var/cache/akmods/rtl88xxau/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
