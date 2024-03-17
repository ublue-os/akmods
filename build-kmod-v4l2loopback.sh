#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


if [ "40" == "${RELEASE}" ]; then
  echo "SKIPPED BUILD of v4l2loopback: compile failure on F40 as of 2024-03-17"
  exit 0
fi

### BUILD v4l2loopbak (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-v4l2loopback-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/${KERNEL}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
