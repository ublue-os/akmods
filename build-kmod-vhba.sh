#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "$RELEASE" -lt 39 ]]; then
  echo "SKIPPED BUILD of vhba on Fedora $RELEASE"
  exit 0
fi

wget "https://copr.fedorainfracloud.org/coprs/rok/cdemu/repo/fedora-${COPR_RELEASE}/rok-cdemu-fedora-${COPR_RELEASE}.repo" -O /etc/yum.repos.d/_copr_rok-cdemu.repo

### BUILD vhba (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-vhba-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod vhba
modinfo /usr/lib/modules/${KERNEL}/extra/vhba/vhba.ko.xz > /dev/null \
|| (find /var/cache/akmods/vhba/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_rok-cdemu.repo
