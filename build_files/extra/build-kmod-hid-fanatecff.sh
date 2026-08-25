#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"
DIST="$(rpm -E '%{dist}')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/terra.repo /etc/yum.repos.d/
# Fedora: import the Terra key for this release; EL builds already have
# the Terra EL key imported by build-prep.sh
if [[ "${DIST}" != .el* ]]; then
    curl -LsSf -o /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}" \
        "https://raw.githubusercontent.com/terrapkg/packages/f${RELEASE}/anda/terra/gpg-keys/RPM-GPG-KEY-terra${RELEASE}"
    rpmkeys --import /etc/pki/rpm-gpg/RPM-GPG-KEY-terra"${RELEASE}"
fi

### BUILD hid-fanatecff (succeed or fail-fast with debug output)
dnf install -y \
    akmod-hid-fanatecff-*"${DIST}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod hid-fanatecff
modinfo /usr/lib/modules/"${KERNEL}"/extra/hid-fanatecff/hid-fanatec.ko.xz > /dev/null \
|| (find /var/cache/akmods/hid-fanatecff/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/extra
dnf download --destdir /var/cache/rpms/extra \
    hid-fanatecff \
    hid-fanatecff-akmod-modules

rm -f /var/cache/rpms/extra/*.src.rpm

rm -f /etc/yum.repos.d/terra.repo
