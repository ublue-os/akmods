#!/bin/sh

set -oeux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [ "40" == "${RELEASE}" ]; then
  echo "SKIPPED BUILD of xpadneo: negativo17 not supporting F40 yet"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo /etc/yum.repos.d/

### BUILD xpadneo (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-xpadneo-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod xpadneo
modinfo /usr/lib/modules/${KERNEL}/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
|| (find /var/cache/akmods/xpadneo/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
