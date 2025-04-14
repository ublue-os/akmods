#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

cp /tmp/ublue-os-akmods-addons/rpmbuild/SOURCES/_copr_ublue-os-akmods.repo /etc/yum.repos.d/

### BUILD acpi_call (succeed or fail-fast with debug output)
dnf install -y \
    akmod-acpi_call-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod acpi_call
modinfo /usr/lib/modules/${KERNEL}/extra/acpi_call/acpi_call.ko.xz >/dev/null ||
    (find /var/cache/akmods/acpi_call/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ublue-os-akmods.repo
