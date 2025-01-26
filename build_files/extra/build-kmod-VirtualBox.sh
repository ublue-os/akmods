#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD VirtualBox (succeed or fail-fast with debug output)
dnf install -y \
    akmod-VirtualBox-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod VirtualBox
modinfo /usr/lib/modules/${KERNEL}/extra/VirtualBox/{vboxdrv,vboxnetadp,vboxnetflt}.ko.xz > /dev/null \
|| (find /var/cache/akmods/VirtualBox/ -name \*.log -print -exec cat {} \; && exit 1)
