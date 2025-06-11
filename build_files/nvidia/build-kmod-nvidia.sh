#!/bin/sh

set -oeux pipefail

ARCH=$(rpm -E %_arch)
KERNEL_MODULE_TYPE="${1:-kernel}"

if [[ "${KERNEL_FLAVOR}" =~ "centos" ]]; then
    RELEASE="$(rpm -E '%centos')"
    DIST_RELEASE="el${RELEASE}"
    # enable negativo17
    cp /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-epel-nvidia.repo /etc/yum.repos.d/
else
    RELEASE="$(rpm -E '%fedora')"
    DIST_RELEASE="fc${RELEASE}"
    # disable rpmfusion and enable negativo17
    sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/rpmfusion-*.repo
    cp /tmp/ublue-os-nvidia-addons/rpmbuild/SOURCES/negativo17-fedora-nvidia.repo /etc/yum.repos.d/
fi

cd /tmp

### BUILD nvidia


dnf install -y \
    akmod-nvidia*.${DIST_RELEASE}.${ARCH}

# Either successfully build and install the kernel modules, or fail early with debug output
rpm -qa |grep nvidia
KERNEL_VERSION="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-nvidia" --queryformat '%{VERSION}-%{RELEASE}')" ".${DIST_RELEASE}")"

sed -i "s/^MODULE_VARIANT=.*/MODULE_VARIANT=$KERNEL_MODULE_TYPE/" /etc/nvidia/kernel.conf

akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/nvidia/${NVIDIA_AKMOD_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

# View license information
modinfo -l /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

# create a directory for later copying of resulting nvidia specific artifacts
mkdir -p /var/cache/rpms/kmods/nvidia


cat <<EOF > /var/cache/rpms/kmods/nvidia-vars
KERNEL_VERSION=${KERNEL_VERSION}
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE}
RELEASE="${RELEASE}.${ARCH}"
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
EOF
