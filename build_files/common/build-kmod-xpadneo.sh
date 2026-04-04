#!/bin/sh

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo /etc/yum.repos.d/
curl -LsSf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}" \
    "https://raw.githubusercontent.com/terrapkg/packages/f${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terra${RELEASE}"
rpmkeys --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}"

### BUILD xpadneo
dnf install -y \
    akmod-xpadneo-*.fc"${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod xpadneo
modinfo /usr/lib/modules/"${KERNEL}"/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
|| (find /var/cache/akmods/xpadneo/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    xpadneo-kmod-common

rm -f /var/cache/rpms/common/*.src.rpm

rm -f /etc/yum.repos.d/terra.repo
