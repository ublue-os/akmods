#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD framework-laptop (succeed or fail-fast with debug output)
dnf install -y \
    akmod-framework-laptop-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod framework-laptop
modinfo /usr/lib/modules/${KERNEL}/extra/framework-laptop/framework_laptop.ko.xz > /dev/null \
|| (find /var/cache/akmods/framework_laptop/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
