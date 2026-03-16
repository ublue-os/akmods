#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

TERRA_REPO="--nogpgcheck --repofrompath=terra,https://repos.fyralabs.com/terra${RELEASE}"

### BUILD xonedo (succeed or fail-fast with debug output)
dnf install -y ${TERRA_REPO} \
    xonedo xonedo-firmware xonedo-kmod
akmods --force --kernels "${KERNEL}" --kmod xonedo
modinfo /usr/lib/modules/"${KERNEL}"/extra/xone/xone_{dongle,gip,gip_gamepad,gip_headset,gip_chatpad,gip_madcatz_strat,gip_madcatz_glam,gip_pdp_jaguar}.ko.xz > /dev/null \
|| (find /var/cache/akmods/xonedo/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download ${TERRA_REPO} --destdir /var/cache/rpms/common \
    xonedo xonedo-firmware xonedo-kmod

rm -f /var/cache/rpms/common/*.src.rpm
