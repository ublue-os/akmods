#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD xone (succeed or fail-fast with debug output)
dnf install -y \
    akmod-xone-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod xone
modinfo /usr/lib/modules/"${KERNEL}"/extra/xone/xone_{dongle,gip,gip_gamepad,gip_headset,gip_chatpad,gip_madcatz_strat,gip_madcatz_glam,gip_pdp_jaguar}.ko.xz > /dev/null \
|| (find /var/cache/akmods/xone/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
