#!/usr/bin/bash

set ${CI:+-x} -euo pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

DIST="$(rpm -E '%{dist}')"
if [[ "${DIST}" == .el* ]]; then
    # EL: modules come from the distro-matched ublue akmods COPR; skip cleanly until packaged there
    cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/ 2>/dev/null || true
    if [[ -z "$(dnf -q --assumeyes repoquery --available "akmod-v4l2loopback-*${DIST}.${ARCH}" 2>/dev/null || true)" ]]; then
        echo "SKIPPED: v4l2loopback (no package for ${DIST})"
        exit 0
    fi
fi

### BUILD v4l2loopbak (succeed or fail-fast with debug output)
dnf install -y \
    akmod-v4l2loopback-*"${DIST}.${ARCH}"
# the kmod spec BuildRequires help2man, which CentOS base images lack
if [[ "${DIST}" == .el* ]]; then
    dnf install -y help2man
fi
akmods --force --kernels "${KERNEL}" --kmod v4l2loopback
modinfo /usr/lib/modules/"${KERNEL}"/extra/v4l2loopback/v4l2loopback.ko.xz > /dev/null \
|| (find /var/cache/akmods/v4l2loopback/ -name \*.log -print -exec cat {} \; && exit 1)

mkdir -p /var/cache/rpms/common
dnf download --destdir /var/cache/rpms/common \
    v4l2loopback

rm -f /var/cache/rpms/common/*.src.rpm
