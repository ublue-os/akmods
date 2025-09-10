#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 41 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

curl -LsSf -o /etc/yum.repos.d/_copr_gladion136-tuxedo-drivers-kmod.repo "https://copr.fedorainfracloud.org/coprs/gladion136/tuxedo-drivers-kmod/repo/fedora-${COPR_RELEASE}/gladion136-tuxedo-drivers-kmod-fedora-${COPR_RELEASE}.repo"

dnf install -y \
    "akmod-tuxedo-drivers-*.fc${RELEASE}.${ARCH}"

akmods --force --kernels "${KERNEL}" --kmod tuxedo-drivers-kmod

for file in /usr/lib/modules/${KERNEL}/extra/tuxedo-drivers/*.ko.xz; do
    modinfo "$file" > /dev/null \
    || (find /var/cache/akmods/tuxedo-drivers/ -name \*.log -print -exec cat {} \; && exit 1)
done

rm -f /etc/yum.repos.d/_copr_gladion136-tuxedo-drivers-kmod.repo
