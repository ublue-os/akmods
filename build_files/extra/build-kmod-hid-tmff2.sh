#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo /etc/yum.repos.d/
curl -LsSf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}" \
    "https://raw.githubusercontent.com/terrapkg/packages/f${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terra${RELEASE}"
rpmkeys --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}"

### BUILD hid-tmff2 (succeed or fail-fast with debug output)
dnf install -y \
    akmod-hid-tmff2-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod hid-tmff2
modinfo /usr/lib/modules/"${KERNEL}"/extra/hid-tmff2/hid-tmff-new.ko.xz > /dev/null \
|| (find /var/cache/akmods/hid-tmff2/ -name \*.log -print -exec cat {} \; && exit 1)
modinfo /usr/lib/modules/"${KERNEL}"/extra/hid-tmff2/hid-tminit-new.ko.xz > /dev/null \
|| (find /var/cache/akmods/hid-tmff2/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    hid-tmff2

rm -f /var/cache/rpms/extra/*.src.rpm

rm -f /etc/yum.repos.d/terra.repo
