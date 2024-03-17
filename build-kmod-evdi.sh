#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [ "40" == "${RELEASE}" ]; then
  echo "SKIPPED BUILD of evdi: negativo17 not supporting F40 yet"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo /etc/yum.repos.d/

### BUILD evdi (succeed or fail-fast with debug output)
export CFLAGS="-fno-pie -no-pie"
rpm-ostree install \
    akmod-evdi-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod evdi
modinfo /usr/lib/modules/${KERNEL}/extra/evdi/evdi.ko.xz > /dev/null \
|| (find /var/cache/akmods/evdi/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
unset CFLAGS
