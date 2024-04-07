#!/bin/sh

set -oeux pipefail



ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -lt "39" ]] && [[ "${KERNEL_FLAVOR}" != "main" ]]; then
  echo "SKIPPED BUILD of framework-kmod: I don't believe this is suppose to work on 38?"
  exit 0
fi

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

rpm-ostree install \
    framework_laptop-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod framework-laptop
modinfo /usr/lib/modules/${KERNEL}/extra/framework-laptop-tests/framework-laptop.ko.xz > /dev/null \
|| (find /var/cache/akmods/framework-laptop-tests/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
