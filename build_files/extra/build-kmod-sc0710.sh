#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo /etc/yum.repos.d/
curl -LsSf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}" \
    "https://raw.githubusercontent.com/terrapkg/packages/f${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terra${RELEASE}"
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}"

### BUILD sc0710 (succeed or fail-fast with debug output)
dnf install -y \
    akmod-sc0710-*.fc"${RELEASE}"."${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod sc0710
modinfo /usr/lib/modules/"${KERNEL}"/extra/sc0710/sc0710.ko.xz > /dev/null \
|| (find /var/cache/akmods/sc0710/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    sc0710

rm -f /var/cache/rpms/extra/*.src.rpm

rm -f /etc/yum.repos.d/terra.repo
