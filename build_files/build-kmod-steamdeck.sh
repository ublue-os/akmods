#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    akmod-steamdeck-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod steamdeck
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck/steamdeck.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck/steamdeck-hwmon.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/${KERNEL}/extra/steamdeck/{extcon,leds}-steamdeck.ko.xz > /dev/null \
|| (find /var/cache/akmods/steamdeck/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
