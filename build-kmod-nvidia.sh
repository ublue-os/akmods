#!/bin/sh

set -oeux pipefail

NVIDIA_MAJOR_VERSION=${1}

RELEASE="$(rpm -E '%fedora.%_arch')"
echo NVIDIA_MAJOR_VERSION=${NVIDIA_MAJOR_VERSION}

cd /tmp

### BUILD nvidia
# nvidia 520.xxx and newer currently don't have a -$VERSIONxx suffix in their
# package names
if [[ "${NVIDIA_MAJOR_VERSION}" -ge 520 ]]; then
    NVIDIA_PACKAGE_NAME="nvidia"
else
    NVIDIA_PACKAGE_NAME="nvidia-${NVIDIA_MAJOR_VERSION}xx"
fi

dnf install -y \
    akmod-${NVIDIA_PACKAGE_NAME}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE} \
    xorg-x11-drv-${NVIDIA_PACKAGE_NAME}-{,cuda,devel,kmodsrc,power}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE}

# Either successfully build and install the kernel modules, or fail early with debug output
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
NVIDIA_AKMOD_VERSION="$(basename "$(rpm -q "akmod-${NVIDIA_PACKAGE_NAME}" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"
NVIDIA_LIB_VERSION="$(basename "$(rpm -q "xorg-x11-drv-${NVIDIA_PACKAGE_NAME}" --queryformat '%{VERSION}-%{RELEASE}')" ".fc${RELEASE%%.*}")"
NVIDIA_FULL_VERSION="$(rpm -q "xorg-x11-drv-${NVIDIA_PACKAGE_NAME}" --queryformat '%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}')"


akmods --force --kernels "${KERNEL_VERSION}" --kmod "${NVIDIA_PACKAGE_NAME}"

modinfo /usr/lib/modules/${KERNEL_VERSION}/extra/${NVIDIA_PACKAGE_NAME}/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
(cat /var/cache/akmods/${NVIDIA_PACKAGE_NAME}/${NVIDIA_AKMOD_VERSION}-for-${KERNEL_VERSION}.failed.log && exit 1)

cat <<EOF > /var/cache/rpms/kmods/nvidia-vars.${NVIDIA_MAJOR_VERSION}
KERNEL_VERSION=${KERNEL_VERSION}
RELEASE=${RELEASE}
NVIDIA_PACKAGE_NAME=${NVIDIA_PACKAGE_NAME}
NVIDIA_MAJOR_VERSION=${NVIDIA_MAJOR_VERSION}
NVIDIA_FULL_VERSION=${NVIDIA_FULL_VERSION}
NVIDIA_AKMOD_VERSION=${NVIDIA_AKMOD_VERSION}
NVIDIA_LIB_VERSION=${NVIDIA_LIB_VERSION}
EOF

# cleanup for other nvidia builds
dnf remove -y \
    akmod-${NVIDIA_PACKAGE_NAME}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE} \
    xorg-x11-drv-${NVIDIA_PACKAGE_NAME}-{,cuda,devel,kmodsrc,power}*:${NVIDIA_MAJOR_VERSION}.*.fc${RELEASE}
