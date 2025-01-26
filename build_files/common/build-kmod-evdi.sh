#!/bin/bash

set -eoux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/negativo17-fedora-multimedia.repo /etc/yum.repos.d/

if [[ "${FEDORA_MAJOR_VERSION}" -ge 42 ]]; then
  if dnf search displaylink | grep -qv "displaylink"; then
    echo "Skipping build of evdi; displaylink net yet provided by negativo17"
    exit 0
  fi
fi

set -e pipefail

### BUILD evdi (succeed or fail-fast with debug output)
export CFLAGS="-fno-pie -no-pie"
dnf install -y \
  kmod-evdi*.fc"${RELEASE}.${ARCH}" akmod-evdi-*.fc"${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod evdi
modinfo /usr/lib/modules/"${KERNEL}"/extra/evdi/evdi.ko.xz >/dev/null ||
  (find /var/cache/akmods/evdi/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo
unset CFLAGS
