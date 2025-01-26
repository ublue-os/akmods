#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_ssweeny-system76-io.repo \
    "https://copr.fedorainfracloud.org/coprs/ssweeny/system76-hwe/repo/fedora-${COPR_RELEASE}/ssweeny-system76-hwe-fedora-${COPR_RELEASE}.repo"

### BUILD system76-io (succeed or fail-fast with debug output)
dnf install -y \
    "akmod-system76-io-*.fc${RELEASE}.${ARCH}"
akmods --force --kernels "${KERNEL}" --kmod system76-io
modinfo "/usr/lib/modules/${KERNEL}/extra/system76-io/system76-io.ko.xz" >/dev/null ||
    (find /var/cache/akmods/system76-io/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_ssweeny-system76-hwe.repo
