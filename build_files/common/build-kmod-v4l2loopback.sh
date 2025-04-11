#!/bin/sh

set -oeux pipefail

# TODO: completely remove this script once F41 no longer is built for ublue

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 42 ]]; then
  echo "skipping v4l2loopback: made obsolete by PipeWire provided with Fedora 42"
else
  ### BUILD v4l2loopback (succeed or fail-fast with debug output)
  dnf install -y \
      akmod-v4l2loopback-*.fc${RELEASE}.${ARCH}
  akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
  modinfo /usr/lib/modules/${KERNEL}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
  || (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
fi
