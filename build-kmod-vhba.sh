#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD wl (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-vhba-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod akmod-vhba
modinfo /usr/lib/modules/${KERNEL}/extra/akmod-vhba/akmod-vhba.ko.xz > /dev/null \
|| (find /var/cache/akmods/akmod-vhba/ -name \*.log -print -exec cat {} \; && exit 1)
