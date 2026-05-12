#!/usr/bin/bash
set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo /etc/yum.repos.d/
curl -LsSf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}" \
    "https://raw.githubusercontent.com/terrapkg/packages/f${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terra${RELEASE}"
rpmkeys --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}"

### BUILD nct6687d (succeed or fail-fast with debug output)
dnf install -y \
    akmod-nct6687d-*.fc"${RELEASE}"."${ARCH}"

akmods --force --kernels "${KERNEL}" --kmod nct6687d

MODULE="/usr/lib/modules/${KERNEL}/extra/nct6687d/nct6687.ko.xz"
modinfo "${MODULE}" > /dev/null \
|| (find /var/cache/akmods/nct6687d/ -name \*.log -print -exec cat {} \; && exit 1)

find /var/cache/akmods/nct6687d/ -type f -name "kmod-nct6687d-${KERNEL}-*.rpm" | grep -q . \
|| (echo "ERROR: expected kmod-nct6687d-${KERNEL}-*.rpm was not produced" >&2; \
    find /var/cache/akmods/nct6687d/ -maxdepth 5 -type f -print >&2; \
    find /var/cache/akmods/nct6687d/ -name \*.log -print -exec cat {} \; ; \
    exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    nct6687d \
    nct6687d-akmod-modules

rm -f /var/cache/rpms/extra/*.src.rpm
rm -f /etc/yum.repos.d/terra.repo
