#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

### Add TLP repo
dnf install -y https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm

### BUILD tp_smapi (succeed or fail-fast with debug output)
if [[ "${RELEASE}" = 41 ]]; then
  dnf --enablerepo=tlp-updates-testing install -y \
    "akmod-tp_smapi-*.fc${RELEASE}.${ARCH}"
else
  dnf install -y \
    "akmod-tp_smapi-*.fc${RELEASE}.${ARCH}"
fi
akmods --force --kernels "${KERNEL}" --kmod tp_smapi
modinfo "/usr/lib/modules/${KERNEL}/extra/tp_smapi/tp_smapi.ko.xz" >/dev/null ||
  (find /var/cache/akmods/tp_smapi/ -name \*.log -print -exec cat {} \; && exit 1)
