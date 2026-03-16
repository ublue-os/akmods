#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

# Skip for kernels that ship v4l2loopback in-tree (e.g., Nobara/OGC)
if rpm -q --provides "${KERNEL_NAME}-core-${KERNEL}" 2>/dev/null | grep -q "v4l2loopback-kmod"; then
    echo "Skipping v4l2loopback: provided in-tree by ${KERNEL_NAME}-core-${KERNEL}"
    exit 0
fi

### BUILD v4l2loopbak (succeed or fail-fast with debug output)
dnf install -y \
    akmod-v4l2loopback-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/"${KERNEL}"/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    v4l2loopback

rm -f /var/cache/rpms/common/*.src.rpm
