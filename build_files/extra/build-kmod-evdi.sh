#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo /etc/yum.repos.d/

### BUILD evdi (succeed or fail-fast with debug output)
export CFLAGS="-fno-pie -no-pie"
dnf install -y \
    kmod-evdi*.fc"${RELEASE}.${ARCH}" akmod-evdi-*.fc"${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod evdi
modinfo /usr/lib/modules/"${KERNEL}"/extra/evdi/evdi.ko.xz > /dev/null \
|| (find /var/cache/akmods/evdi/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    libevdi \
    displaylink

rm -f /var/cache/rpms/extra/*.src.rpm

rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
unset CFLAGS
