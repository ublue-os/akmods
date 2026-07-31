#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_rok-cdemu.repo /etc/yum.repos.d/

### BUILD vhba (succeed or fail-fast with debug output)
dnf install -y \
    akmod-vhba-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod vhba
modinfo /usr/lib/modules/"${KERNEL}"/extra/vhba/vhba.ko.xz > /dev/null \
|| (find /var/cache/akmods/vhba/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_rok-cdemu.repo
