#!/bin/sh

set -oeux pipefail

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

rpm-ostree install \
    akmod-steamdeck-dwc3-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod steamdeck-dwc3
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck-dwc3/dwc3.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck-dwc3/dwc3-{pci,haps}-hwmon.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
