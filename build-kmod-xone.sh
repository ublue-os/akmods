#!/bin/sh

set -oeux pipefail

mkdir -p /var/cache/repos

wget https://negativo17.org/repos/fedora-steam.repo -O /var/cache/repos/fedora-steam.repo

cp /var/cache/repos/fedora-steam.repo /etc/yum.repos.d/

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"


### BUILD xone (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-xone-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod xone
modinfo /usr/lib/modules/${KERNEL}/extra/xone/xone-{dongle,gip-chatpad,gip-gamepad,gip-guitar,gip-headset,gip,wired}.ko.xz > /dev/null \
|| (find /var/cache/akmods/xone/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/fedora-steam.repo
