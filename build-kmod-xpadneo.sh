#!/bin/sh

set -oux pipefail


ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo /etc/yum.repos.d/

if [[ "${FEDORA_MAJOR_VERSION}" -ge 41 ]]; then
  if dnf search akmod-xpadneo|grep -qv "akmod-xpadneo"; then
    echo "Skipping build of xpadneo; net yet provided by negativo17"
    exit 0
  fi
fi

set -e pipefail

### BUILD xpadneo (succeed or fail-fast with debug output)
dnf install -y \
    akmod-xpadneo-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod xpadneo
modinfo /usr/lib/modules/${KERNEL}/extra/xpadneo/hid-xpadneo.ko.xz > /dev/null \
|| (find /var/cache/akmods/xpadneo/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
