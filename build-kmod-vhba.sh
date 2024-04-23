#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "$RELEASE" -lt 39 ]]; then
  echo "SKIPPED BUILD of gasket: compile failure on kernel 6.8 as of 2024-03-17"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_rok-cdemu.repo /etc/yum.repos.d/

### BUILD vhba (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-vhba-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod vhba
modinfo /usr/lib/modules/${KERNEL}/extra/vhba/vhba.ko.xz > /dev/null \
|| (find /var/cache/akmods/vhba/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_rok-cdemu.repo
