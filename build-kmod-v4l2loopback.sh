#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD v4l2loopbak (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-v4l2loopback-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/${KERNEL}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
