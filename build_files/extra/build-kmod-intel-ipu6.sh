#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

### BUILD intel-ipu6 (succeed or fail-fast with debug output)
dnf install -y \
    akmod-intel-ipu6-*.fc"${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod intel-ipu6
modinfo /usr/lib/modules/"${KERNEL}"/extra/intel-ipu6/intel-ipu6.ko.xz > /dev/null \
|| (find /var/cache/akmods/intel-ipu6/ -name \*.log -print -exec cat {} \; && exit 1)
