#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

# Skip for aarch64
if [[ "${ARCH}" =~ aarch64 ]]; then
    exit 0
fi


### BUILD wl (succeed or fail-fast with debug output)
dnf install -y \
    akmod-wl-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/"${KERNEL}"/extra/wl/wl.ko.xz > /dev/null \
|| (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    broadcom-wl

rm -f /var/cache/rpms/common/*.src.rpm
