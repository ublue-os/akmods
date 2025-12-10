#!/usr/bin/bash

set "${CI:+-x}" -euo pipefail

ARCH="$(rpm -E '%_arch')"
KMOD_REPO="${1:-nvidia}"

DIST="$(rpm -E '%dist')"
DIST="${DIST#.}"
VARS_KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    # enable negativo17
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-epel-${KMOD_REPO}.repo" /etc/yum.repos.d/
else
    # disable rpmfusion and enable negativo17
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/rpmfusion-*.repo
    cp "/tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-fedora-${KMOD_REPO}.repo" /etc/yum.repos.d/
fi
export KERNEL_MODULE_TYPE=open
if [[ "${KMOD_REPO}" =~ "lts" ]]; then
    export KERNEL_MODULE_TYPE=kernel
fi
DEPRECATED_RELEASE="${DIST}.${ARCH}"

cd /tmp

### BUILD nvidia

# query latest available driver in repo
DRIVER_VERSION=$(dnf info akmod-nvidia | grep -E '^Version|^Release' | awk '{print $3}' | xargs | sed 's/\ /-/')

# only install the version of akmod-nviida which matches available nvidia-driver
# this works around situations where a new version may be released but not for one arch
dnf install -y \
    "akmod-nvidia-${DRIVER_VERSION}"

# Either successfully build and install the kernel modules, or fail early with debug output
rpm -qa |grep nvidia
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-nvidia" --queryformat '%{VERSION}-%{RELEASE}')" ".${DIST}")"

akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

modinfo /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/nvidia/"${NVIDIA_AKMOD_VERSION}"-for-"${KERNEL_VERSION}".failed.log && exit 1)

# View license information
modinfo -l /usr/lib/modules/"${KERNEL_VERSION}"/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# create a directory for later copying of resulting nvidia specific artifacts
mkdir -p /var/cache/rpms/kmods/nvidia

# TODO: remove deprecated RELEASE var which clobbers more typical meanings/usages of RELEASE
cat <<EOF > /var/cache/rpms/kmods/nvidia-vars
DIST_ARCH="${DIST}.${ARCH}"
KERNEL_VERSION=${VARS_KERNEL_VERSION}
# KERNEL_MODULE_TYPE: deprecated as of 2025-12-07, in favor of KMOD_REPO
# latest drivers are always "open", and LTS driver is always "kernel"
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
# KMOD_REPO: latest drivers are "nvidia", and LTS driver is "nvidia-lts"
KMOD_REPO=${KMOD_REPO}
RELEASE="${DEPRECATED_RELEASE}"
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
EOF
