#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -lt "40" ]]; then
  echo "SKIPPED BUILD of v4l2loopback: compile failure on 6.8 kernels in F38/F39 as of 2024-03-27"
  exit 0
fi

### BUILD v4l2loopbak (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-v4l2loopback-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/${KERNEL}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
