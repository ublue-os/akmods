#!/bin/sh

set -oeux pipefail


### PREPARE REPOS
ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD v4l2loopbak (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-v4l2loopback-*.fc${RELEASE}.${ARCH}
V4L2LOOP_AKMOD_VERSION="$(basename "$(rpm -q "akmod-v4l2loopback" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" ".fc${RELEASE%%.*}")"
akmods --force --kernels "${KERNEL}" --kmod "v4l2loopback"
modinfo /usr/lib/modules/${KERNEL}/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)
#|| (cat /var/cache/akmods/v4l2loopback/${V4L2LOOP_AKMOD_VERSION}.failed.log && exit 1)

